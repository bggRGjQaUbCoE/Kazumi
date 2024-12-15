import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';

class DanmakuSettingsWindow extends StatefulWidget {
  final DanmakuController danmakuController;
  const DanmakuSettingsWindow({super.key, required this.danmakuController});

  @override
  State<DanmakuSettingsWindow> createState() => _DanmakuSettingsWindowState();
}

class _DanmakuSettingsWindowState extends State<DanmakuSettingsWindow> {
  Box setting = GStorage.setting;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('弹幕字号'),
              Slider(
                value: widget.danmakuController.option.fontSize,
                min: 10,
                max: 32,
                divisions: 22,
                label: widget.danmakuController.option.fontSize.toString(),
                onChanged: (value) {
                  setState(() => widget.danmakuController.updateOption(
                        widget.danmakuController.option.copyWith(
                          fontSize: value,
                        ),
                      ));
                  setting.put(SettingBoxKey.danmakuFontSize, value);
                },
              ),
              const Text('弹幕描边'),
              Slider(
                value: widget.danmakuController.option.strokeWidth,
                min: 0,
                max: 3,
                divisions: 6,
                label: widget.danmakuController.option.strokeWidth.toString(),
                onChanged: (value) {
                  setState(() => widget.danmakuController.updateOption(
                        widget.danmakuController.option.copyWith(
                          strokeWidth: value,
                        ),
                      ));
                  setting.put(SettingBoxKey.danmakuStrokeWidth, value);
                },
              ),
              const Text('弹幕粗细'),
              Slider(
                value: widget.danmakuController.option.fontWeight.toDouble(),
                min: 0,
                max: 8,
                divisions: 8,
                label:
                    (widget.danmakuController.option.fontWeight + 1).toString(),
                onChanged: (value) {
                  setState(() => widget.danmakuController.updateOption(
                        widget.danmakuController.option.copyWith(
                          fontWeight: value.round(),
                        ),
                      ));
                  setting.put(SettingBoxKey.danmakuFontWeight, value.round());
                },
              ),
              const Text('弹幕区域'),
              Slider(
                value: widget.danmakuController.option.area,
                min: 0,
                max: 1,
                divisions: 4,
                label:
                    '${(widget.danmakuController.option.area * 100).round()}%',
                onChanged: (value) {
                  setState(() => widget.danmakuController.updateOption(
                        widget.danmakuController.option.copyWith(
                          area: value,
                        ),
                      ));
                  setting.put(SettingBoxKey.danmakuArea, value);
                },
              ),
              const Text('弹幕不透明度'),
              Slider(
                value: widget.danmakuController.option.opacity,
                min: 0.1,
                max: 1,
                divisions: 9,
                label:
                    '${(widget.danmakuController.option.opacity * 100).round()}%',
                onChanged: (value) {
                  setState(() => widget.danmakuController.updateOption(
                        widget.danmakuController.option.copyWith(
                          opacity: value,
                        ),
                      ));
                  setting.put(SettingBoxKey.danmakuOpacity,
                      double.parse(value.toStringAsFixed(1)));
                },
              ),
              ListTile(
                title: const Text('隐藏滚动弹幕'),
                trailing: Switch(
                  value: widget.danmakuController.option.hideScroll,
                  onChanged: (value) {
                    setState(() => widget.danmakuController.updateOption(
                          widget.danmakuController.option.copyWith(
                            hideScroll: value,
                          ),
                        ));
                    setting.put(SettingBoxKey.danmakuScroll, !value);
                  },
                ),
              ),
              ListTile(
                title: const Text('隐藏顶部弹幕'),
                trailing: Switch(
                  value: widget.danmakuController.option.hideTop,
                  onChanged: (value) {
                    setState(() => widget.danmakuController.updateOption(
                          widget.danmakuController.option.copyWith(
                            hideTop: value,
                          ),
                        ));
                    setting.put(SettingBoxKey.danmakuTop, !value);
                  },
                ),
              ),
              ListTile(
                title: const Text('隐藏底部弹幕'),
                trailing: Switch(
                  value: widget.danmakuController.option.hideBottom,
                  onChanged: (value) {
                    setState(() => widget.danmakuController.updateOption(
                          widget.danmakuController.option.copyWith(
                            hideBottom: value,
                          ),
                        ));
                    setting.put(SettingBoxKey.danmakuBottom, !value);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
