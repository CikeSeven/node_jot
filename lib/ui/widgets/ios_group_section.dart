import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import 'ios_frosted_panel.dart';

/// 分组区域组件。
///
/// 由标题行 + 毛玻璃内容容器组成，可选内容区域撑满剩余空间。
class IosGroupSection extends StatelessWidget {
  const IosGroupSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(14),
    this.expandBody = false,
    this.bottomSpacing = AppSpacing.l,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool expandBody;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 分组之间的垂直间距。
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        mainAxisSize: expandBody ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分组标题行：左侧标题 + 右侧可选操作区。
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          // 分组内容容器：支持普通高度或填满剩余空间。
          if (expandBody)
            Expanded(child: IosFrostedPanel(padding: padding, child: child))
          else
            IosFrostedPanel(padding: padding, child: child),
        ],
      ),
    );
  }
}
