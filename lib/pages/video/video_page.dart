import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/player/episode_comments_sheet.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/webview/webview_item.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/pages/player/player_item.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage>
    with SingleTickerProviderStateMixin {
  Box setting = GStorage.setting;
  final InfoController infoController = Modular.get<InfoController>();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PlayerController playerController = Modular.get<PlayerController>();
  final HistoryController historyController = Modular.get<HistoryController>();
  late bool playResume;

  ScrollController scrollController = ScrollController();
  late GridObserverController observerController;
  late AnimationController animation;
  late Animation<Offset> _rightOffsetAnimation;

  // 当前播放列表
  late int currentRoad;

  final _key = GlobalKey<ScaffoldState>();
  PersistentBottomSheetController? _bottomSheetController;

  @override
  void initState() {
    super.initState();
    observerController = GridObserverController(controller: scrollController);
    animation = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _rightOffsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOut,
    ));
    // WakelockPlus.enable();
    videoPageController.currentEpisode = 1;
    videoPageController.currentRoad = 0;
    videoPageController.historyOffset = 0;
    videoPageController.showTabBody = true;
    playResume = setting.get(SettingBoxKey.playResume, defaultValue: true);
    var progress = historyController.lastWatching(
        infoController.bangumiItem, videoPageController.currentPlugin.name);
    if (progress != null) {
      if (videoPageController.roadList.length > progress.road) {
        if (videoPageController.roadList[progress.road].data.length >=
            progress.episode) {
          videoPageController.currentEpisode = progress.episode;
          videoPageController.currentRoad = progress.road;
          if (playResume) {
            videoPageController.historyOffset = progress.progress.inSeconds;
          }
        }
      }
    }
    currentRoad = videoPageController.currentRoad;
  }

  @override
  void dispose() {
    try {
      ScreenBrightnessPlatform.instance.resetApplicationScreenBrightness();
      playerController.mediaPlayer.dispose();
    } catch (_) {}
    observerController.controller?.dispose();
    animation.dispose();
    // WakelockPlus.disable();
    Utils.unlockScreenRotation();
    super.dispose();
  }

  void showDebugConsole() {
    videoPageController.showDebugLog = !videoPageController.showDebugLog;
  }

  void menuJumpToCurrentEpisode() {
    Future.delayed(const Duration(milliseconds: 20), () {
      observerController.jumpTo(
          index: videoPageController.currentEpisode > 1
              ? videoPageController.currentEpisode - 1
              : videoPageController.currentEpisode);
    });
  }

  void openTabBodyAnimated() {
    if (videoPageController.showTabBody) {
      animation.forward();
      menuJumpToCurrentEpisode();
    }
  }

  void closeTabBodyAnimated() {
    animation.reverse();
    Future.delayed(const Duration(milliseconds: 100), () {
      videoPageController.showTabBody = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openTabBodyAnimated();
    });
    return OrientationBuilder(builder: (context, orientation) {
      if (!Utils.isDesktop()) {
        if (orientation == Orientation.landscape &&
            !videoPageController.isFullscreen) {
          Utils.enterFullScreen(lockOrientation: false);
          videoPageController.isFullscreen = true;
          videoPageController.showTabBody = false;
        } else if (orientation == Orientation.portrait &&
            videoPageController.isFullscreen) {
          Utils.exitFullScreen(lockOrientation: false);
          menuJumpToCurrentEpisode();
          videoPageController.isFullscreen = false;
        }
      }
      return Observer(builder: (context) {
        return Scaffold(
          key: _key,
          resizeToAvoidBottomInset: false,
          appBar: ((videoPageController.currentPlugin.useNativePlayer ||
                  videoPageController.isFullscreen)
              ? null
              : SysAppBar(
                  title: Text(videoPageController.title),
                )),
          body: SafeArea(
            top: !videoPageController.isFullscreen,
            bottom: false, // set iOS and Android navigation bar to immersive
            left: !videoPageController.isFullscreen,
            right: !videoPageController.isFullscreen,
            child: (Utils.isDesktop()) ||
                    ((Utils.isTablet()) &&
                        MediaQuery.of(context).size.height <
                            MediaQuery.of(context).size.width)
                ? Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      Container(
                          color: Colors.black,
                          height: MediaQuery.of(context).size.height,
                          width: MediaQuery.of(context).size.width,
                          child: playerBody),
                      if (videoPageController.showTabBody) ...[
                        GestureDetector(
                          onTap: () {
                            closeTabBodyAnimated();
                          },
                          child: Container(
                            color: Colors.black38,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        SlideTransition(
                            position: _rightOffsetAnimation,
                            child: SizedBox(
                                height: MediaQuery.of(context).size.height,
                                width: MediaQuery.of(context).size.width *
                                            1 /
                                            3 >
                                        420
                                    ? 420
                                    : MediaQuery.of(context).size.width * 1 / 3,
                                child: Container(
                                    color: Theme.of(context).canvasColor,
                                    child: GridViewObserver(
                                      controller: observerController,
                                      child: Column(
                                        children: [
                                          tabBar,
                                          tabBody,
                                        ],
                                      ),
                                    ))))
                      ]
                    ],
                  )
                : (!videoPageController.isFullscreen)
                    ? Column(
                        children: [
                          Container(
                              color: Colors.black,
                              height:
                                  MediaQuery.of(context).size.width * 9 / 16,
                              width: MediaQuery.of(context).size.width,
                              child: playerBody),
                          Expanded(
                              child: GridViewObserver(
                            controller: observerController,
                            child: Column(
                              children: [
                                tabBar,
                                tabBody,
                              ],
                            ),
                          ))
                        ],
                      )
                    : Stack(alignment: Alignment.centerRight, children: [
                        Container(
                            color: Colors.black,
                            height: MediaQuery.of(context).size.height,
                            width: MediaQuery.of(context).size.width,
                            child: playerBody),
                        if (videoPageController.showTabBody) ...[
                          GestureDetector(
                            onTap: () {
                              closeTabBodyAnimated();
                            },
                            child: Container(
                              color: Colors.black38,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          SlideTransition(
                              position: _rightOffsetAnimation,
                              child: SizedBox(
                                  height: MediaQuery.of(context).size.height,
                                  width: (Utils.isTablet())
                                      ? MediaQuery.of(context).size.width / 2
                                      : MediaQuery.of(context).size.height,
                                  child: Container(
                                      color: Theme.of(context).canvasColor,
                                      child: GridViewObserver(
                                        controller: observerController,
                                        child: Column(
                                          children: [
                                            tabBar,
                                            tabBody,
                                          ],
                                        ),
                                      ))))
                        ]
                      ]),
          ),
        );
      });
    });
  }

  Widget get playerBody {
    return Stack(
      children: [
        // 日志组件
        Positioned.fill(
          child: Stack(
            children: [
              if (videoPageController.currentPlugin.useNativePlayer &&
                  playerController.loading)
                Positioned.fill(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                            color: Theme.of(context)
                                .colorScheme
                                .tertiaryContainer),
                        const SizedBox(height: 10),
                        const Text('视频资源解析成功, 播放器加载中',
                            style: TextStyle(
                              color: Colors.white,
                            )),
                      ],
                    ),
                  ),
                ),
              Visibility(
                visible: videoPageController.loading,
                child: Container(
                  color: Colors.black,
                  child: Align(
                      alignment: Alignment.center,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiaryContainer),
                            const SizedBox(height: 10),
                            const Text('视频资源解析中',
                                style: TextStyle(
                                  color: Colors.white,
                                )),
                          ],
                        ),
                      )),
                ),
              ),
              Visibility(
                visible: (videoPageController.loading ||
                        (videoPageController.currentPlugin.useNativePlayer &&
                            playerController.loading)) &&
                    videoPageController.showDebugLog,
                child: Container(
                  color: Colors.black,
                  child: Align(
                    alignment: Alignment.center,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: videoPageController.logLines.length,
                      itemBuilder: (context, index) {
                        return Text(
                          videoPageController.logLines.isEmpty
                              ? ''
                              : videoPageController.logLines[index],
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (videoPageController.currentPlugin.useNativePlayer ||
                  videoPageController.isFullscreen)
                Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () {
                              if (videoPageController.isFullscreen == true &&
                                  !Utils.isTablet()) {
                                Utils.exitFullScreen();
                                menuJumpToCurrentEpisode();
                                videoPageController.isFullscreen = false;
                                return;
                              }
                              if (videoPageController.isFullscreen == true) {
                                Utils.exitFullScreen();
                                videoPageController.isFullscreen = false;
                              }
                              Navigator.of(context).pop();
                            },
                          ),
                          const Expanded(
                              child: dtb.DragToMoveArea(
                                  child: SizedBox(height: 40))),
                          IconButton(
                            icon: const Icon(Icons.refresh_outlined,
                                color: Colors.white),
                            onPressed: () {
                              videoPageController.changeEpisode(
                                  videoPageController.currentEpisode,
                                  currentRoad: videoPageController.currentRoad);
                            },
                          ),
                          Visibility(
                              visible: Utils.isDesktop() || Utils.isTablet(),
                              child: IconButton(
                                  onPressed: () {
                                    videoPageController.showTabBody =
                                        !videoPageController.showTabBody;
                                    openTabBodyAnimated();
                                  },
                                  icon: Icon(
                                    videoPageController.showTabBody
                                        ? Icons.menu_open
                                        : Icons.menu_open_outlined,
                                    color: Colors.white,
                                  ))),
                          IconButton(
                            icon: Icon(
                                videoPageController.showDebugLog
                                    ? Icons.bug_report
                                    : Icons.bug_report_outlined,
                                color: Colors.white),
                            onPressed: () {
                              showDebugConsole();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (!(!videoPageController.currentPlugin.useNativePlayer ||
            playerController.loading))
          Positioned.fill(
            child: PlayerItem(
              openMenu: openTabBodyAnimated,
              locateEpisode: menuJumpToCurrentEpisode,
              handleFullscreen: () {
                if (_bottomSheetController != null) {
                  _bottomSheetController?.close();
                  _bottomSheetController = null;
                }
              },
              handleBack: () {
                if (_bottomSheetController != null) {
                  _bottomSheetController?.close();
                  _bottomSheetController = null;
                  return true;
                }
                return false;
              },
              showComment: () {
                // bool needRestart = playerController.playing;
                // playerController.pause();
                dynamic episodeNum = Utils.extractEpisodeNumber(
                    videoPageController
                        .roadList[videoPageController.currentRoad]
                        .identifier[videoPageController.currentEpisode - 1]);
                if (episodeNum == 0 ||
                    episodeNum >
                        videoPageController
                            .roadList[videoPageController.currentRoad]
                            .identifier
                            .length) {
                  episodeNum = videoPageController.currentEpisode;
                }
                _bottomSheetController = _key.currentState?.showBottomSheet(
                  (context) {
                    return EpisodeCommentsSheet(
                      episode: episodeNum,
                    );
                    // return DraggableScrollableSheet(
                    //   expand: false,
                    //   snap: true,
                    //   minChildSize: 0,
                    //   maxChildSize: 1,
                    //   initialChildSize: 1,
                    //   snapSizes: const [1],
                    //   builder: (context, scrollController) {
                    //     return EpisodeCommentsSheet(
                    //       episode: episodeNum,
                    //       scrollController: scrollController,
                    //     );
                    //   },
                    // );
                  },
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  enableDrag: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height >
                              MediaQuery.of(context).size.width
                          ? MediaQuery.of(context).size.height -
                              MediaQuery.of(context).size.width * 9 / 16 -
                              MediaQuery.paddingOf(context).top
                          : MediaQuery.of(context).size.height,
                      maxWidth: MediaQuery.of(context).size.width >
                              MediaQuery.of(context).size.height
                          ? MediaQuery.of(context).size.width * 9 / 16
                          : MediaQuery.of(context).size.width),
                  clipBehavior: Clip.antiAlias,
                );
                //.whenComplete(() {
                // if (needRestart) {
                //   playerController.play();
                // }
                // _focusNode.requestFocus();
                // });
              },
              showDanmakuOffsetSheet: () {
                _bottomSheetController = _key.currentState?.showBottomSheet(
                  (context) {
                    Map<int, List<Danmaku>> oriDanDanmakus = {};
                    if (playerController.danmakuOffset != 0) {
                      playerController.danDanmakus.forEach((key, value) {
                        oriDanDanmakus[key + playerController.danmakuOffset] =
                            value;
                      });
                    } else {
                      oriDanDanmakus = playerController.danDanmakus;
                    }

                    String getLabel() => playerController.danmakuOffset == 0
                        ? '不变'
                        : '${playerController.danmakuOffset < 0 ? '慢' : '快'}${playerController.danmakuOffset.abs()}秒';

                    return StatefulBuilder(
                      builder: (context, setState) {
                        void onChanged(int value) {
                          playerController.danmakuOffset = value;
                          setState(() {});
                          Map<int, List<Danmaku>> danDanmakus = {};
                          oriDanDanmakus.forEach((key, value) {
                            danDanmakus[key - playerController.danmakuOffset] =
                                value;
                          });
                          playerController.danmakuController.clear();
                          playerController.danDanmakus = danDanmakus;
                        }

                        return Scaffold(
                          resizeToAvoidBottomInset: false,
                          appBar: AppBar(
                            automaticallyImplyLeading: false,
                            title: const Text(
                              '弹幕时间轴调整',
                              style: TextStyle(fontSize: 18),
                            ),
                            actions: [
                              IconButton(
                                tooltip: '编辑调整',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      String initialValue = playerController
                                          .danmakuOffset
                                          .toString();
                                      return AlertDialog(
                                        content: TextFormField(
                                          initialValue: initialValue,
                                          autofocus: true,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(signed: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                                RegExp(r'[-\d+]')),
                                          ],
                                          onChanged: (value) {
                                            initialValue = value;
                                          },
                                          decoration: const InputDecoration(
                                            suffixText: 's',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text(
                                              '取消',
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outline),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              onChanged(
                                                  int.tryParse(initialValue) ??
                                                      0);
                                            },
                                            child: const Text('确定'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                tooltip: '关闭',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.clear),
                              ),
                              const SizedBox(width: 16),
                            ],
                          ),
                          body: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(getLabel()),
                              Slider(
                                value:
                                    playerController.danmakuOffset.toDouble(),
                                min: -15,
                                max: 15,
                                divisions: 30,
                                label: getLabel(),
                                onChanged: (value) {
                                  onChanged(value.round());
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  constraints: BoxConstraints(
                      maxHeight: videoPageController.isFullscreen
                          ? MediaQuery.of(context).size.height / 2
                          : MediaQuery.of(context).size.height >
                                  MediaQuery.of(context).size.width
                              ? MediaQuery.of(context).size.height -
                                  MediaQuery.of(context).size.width * 9 / 16 -
                                  MediaQuery.paddingOf(context).top
                              : MediaQuery.of(context).size.height,
                      maxWidth: MediaQuery.of(context).size.width >
                              MediaQuery.of(context).size.height
                          ? MediaQuery.of(context).size.width * 9 / 16
                          : MediaQuery.of(context).size.width),
                );
              },
            ),
          ),

        /// workaround for webview_windows
        /// The webview_windows component cannot be removed from the widget tree; otherwise, it can never be reinitialized.
        Positioned(
            child: SizedBox(
                height: (videoPageController.loading ||
                        videoPageController.currentPlugin.useNativePlayer)
                    ? 0
                    : null,
                child: const WebviewItem()))
      ],
    );
  }

  Widget get tabBar {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(' 合集 '),
          Expanded(
            child: Text(
              videoPageController.title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 34,
            child: TextButton(
              style: ButtonStyle(
                padding: WidgetStateProperty.all(EdgeInsets.zero),
              ),
              onPressed: () {
                KazumiDialog.show(builder: (context) {
                  return AlertDialog(
                    title: const Text('播放列表'),
                    content: StatefulBuilder(builder:
                        (BuildContext context, StateSetter innerSetState) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          for (int i = 1;
                              i <= videoPageController.roadList.length;
                              i++) ...<Widget>[
                            if (i == currentRoad + 1) ...<Widget>[
                              FilledButton(
                                onPressed: () {
                                  KazumiDialog.dismiss();
                                  setState(() {
                                    currentRoad = i - 1;
                                  });
                                },
                                child: Text('播放列表$i'),
                              ),
                            ] else ...[
                              FilledButton.tonal(
                                onPressed: () {
                                  KazumiDialog.dismiss();
                                  setState(() {
                                    currentRoad = i - 1;
                                  });
                                },
                                child: Text('播放列表$i'),
                              ),
                            ]
                          ]
                        ],
                      );
                    }),
                  );
                });
              },
              child: Text(
                '播放列表${currentRoad + 1} ',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget get tabBody {
    var cardList = <Widget>[];
    for (var road in videoPageController.roadList) {
      if (road.name == '播放列表${currentRoad + 1}') {
        int count = 1;
        for (var urlItem in road.data) {
          int count0 = count;
          cardList.add(Container(
            margin: const EdgeInsets.only(bottom: 4), // 改为bottom间距
            child: Material(
              color: Theme.of(context).colorScheme.onInverseSurface,
              borderRadius: BorderRadius.circular(6),
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                onTap: () async {
                  if (count0 == videoPageController.currentEpisode &&
                      videoPageController.currentRoad == currentRoad) {
                    return;
                  }
                  KazumiLogger().log(Level.info, '视频链接为 $urlItem');
                  closeTabBodyAnimated();
                  videoPageController.currentRoad = currentRoad;
                  videoPageController.changeEpisode(count0,
                      currentRoad: videoPageController.currentRoad);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: [
                          if (count0 == (videoPageController.currentEpisode) &&
                              currentRoad ==
                                  videoPageController.currentRoad) ...<Widget>[
                            Image.asset(
                              'assets/images/live.png',
                              color: Theme.of(context).colorScheme.primary,
                              height: 12,
                            ),
                            const SizedBox(width: 6)
                          ],
                          Expanded(
                              child: Text(
                            road.identifier[count0 - 1],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                color: (count0 ==
                                            videoPageController
                                                .currentEpisode &&
                                        currentRoad ==
                                            videoPageController.currentRoad)
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface),
                          )),
                          const SizedBox(width: 2),
                        ],
                      ),
                      const SizedBox(height: 3),
                    ],
                  ),
                ),
              ),
            ),
          ));
          count++;
        }
      }
    }
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 0, right: 8, left: 8),
        child: GridView.builder(
          scrollDirection: Axis.vertical,
          controller: scrollController,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
                (Utils.isDesktop() && !Utils.isWideScreen()) ? 2 : 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 5,
            childAspectRatio: 1.7,
          ),
          itemCount: cardList.length,
          itemBuilder: (context, index) {
            return cardList[index];
          },
        ),
      ),
    );
  }
}
