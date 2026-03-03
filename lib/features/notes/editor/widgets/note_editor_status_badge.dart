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

  final String savedLabel;
  final String countLabel;
  final bool showSavedHint;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700);

    return IosFrostedPanel(
      radius: 999,
      blur: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: AnimatedSize(
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
