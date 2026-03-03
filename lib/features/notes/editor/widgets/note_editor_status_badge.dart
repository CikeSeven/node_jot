import 'package:flutter/material.dart';

import '../../../../ui/widgets/ios_frosted_panel.dart';

/// 编辑页右下角状态卡片。
///
/// 默认仅展示字数；手动保存后左侧扩展展示“已保存”提示。
class NoteEditorStatusBadge extends StatelessWidget {
  const NoteEditorStatusBadge({
    super.key,
    required this.savedLabel,
    required this.countLabel,
    required this.showSavedHint,
  });

  /// “已保存”提示文案（本地化文本由上层传入）。
  final String savedLabel;

  /// 字数统计文案（例如“123 字”）。
  final String countLabel;

  /// 是否显示“已保存”提示。
  final bool showSavedHint;

  @override
  Widget build(BuildContext context) {
    // 使用统一标签字号并加粗，确保在毛玻璃背景上可读。
    final textStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700);

    return IosFrostedPanel(
      radius: 999,
      blur: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: AnimatedSize(
        // 左侧“已保存”出现/消失时平滑过渡宽度，避免突兀跳变。
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSavedHint) ...[
              Text(savedLabel, style: textStyle),
              const SizedBox(width: 8),
            ],
            Text(countLabel, style: textStyle),
          ],
        ),
      ),
    );
  }
}
