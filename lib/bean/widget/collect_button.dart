import 'package:flutter/material.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CollectButton extends StatefulWidget {
  const CollectButton({
    super.key,
    required this.bangumiItem,
    this.withRounder = true,
  });
  final BangumiItem bangumiItem;
  final bool withRounder;

  @override
  State<CollectButton> createState() => _CollectButtonState();
}

class _CollectButtonState extends State<CollectButton> {
  // 1. 在看
  // 2. 想看
  // 3. 搁置
  // 4. 看过
  // 5. 抛弃
  late int collectType;
  final CollectController collectController = Modular.get<CollectController>();

  @override
  void initState() {
    super.initState();
    collectType = collectController.getCollectType(widget.bangumiItem);
  }

  IconData _getIcon(int collectType) => switch (collectType) {
        1 => Icons.favorite,
        2 => Icons.star_rounded,
        3 => Icons.pending_actions,
        4 => Icons.done,
        5 => Icons.heart_broken,
        _ => Icons.favorite_border,
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      tooltip: '',
      // initialValue: collectType,
      child: widget.withRounder
          ? NonClickableIconButton(
              icon: Icon(_getIcon(collectType)),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                _getIcon(collectType),
                color: Colors.white,
              ),
            ),
      itemBuilder: (context) {
        return List.generate(
          6,
          (index) => PopupMenuItem(
            value: index,
            enabled: index != collectType,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getIcon(index)),
                Text([
                  " 未追",
                  " 在看",
                  " 想看",
                  " 搁置",
                  " 看过",
                  " 抛弃",
                ][index])
              ],
            ),
          ),
        );
      },
      onSelected: (value) {
        if (value != collectType && mounted) {
          collectController.addCollect(widget.bangumiItem, type: value);
          setState(() {
            collectType = value;
          });
        }
      },
    );
  }
}

class NonClickableIconButton extends StatelessWidget {
  final Widget icon;
  final double iconSize;
  final Color? iconColor;
  final Color? backgroundColor;
  final double padding;

  const NonClickableIconButton({
    super.key,
    required this.icon,
    this.iconSize = 24.0,
    this.iconColor,
    this.backgroundColor,
    this.padding = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final Color effectiveBackgroundColor =
        backgroundColor ?? Theme.of(context).colorScheme.secondaryContainer;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        shape: BoxShape.circle,
      ),
      child: icon,
    );
  }
}
