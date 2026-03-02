import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// 卡片式列表行组件。
///
/// 用于设备、设置等页面的统一条目样式。
class IosCardTile extends StatelessWidget {
  const IosCardTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            // 左侧图标槽位。
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 主标题。
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 16),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    // 副标题说明。
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 右侧操作槽位（按钮、标签等）。
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
