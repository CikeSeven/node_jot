import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';

/// 编辑页底部状态条区块。
///
/// 展示右侧字数统计，作为覆盖层固定在底部。
class NoteEditorStatusBarSection extends StatelessWidget {
  const NoteEditorStatusBarSection({
    super.key,
    required this.charCountListenable,
    required this.height,
  });

  final ValueListenable<int> charCountListenable;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.9)
            : AppColors.surface.withValues(alpha: 0.9);
    final borderColor = isDark ? AppColors.borderSoftDark : AppColors.borderSoft;
    final textColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: height + safeBottom,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.l,
            4,
            AppSpacing.l,
            4 + safeBottom,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(top: BorderSide(color: borderColor, width: 0.8)),
          ),
          child: Row(
            children: [
              const Spacer(),
              ValueListenableBuilder<int>(
                valueListenable: charCountListenable,
                builder: (context, count, _) {
                  return Text(
                    l10n.charCountLabel(count),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
