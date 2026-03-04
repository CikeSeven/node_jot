import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// 笔记列表空状态组件。
///
/// 当当前列表没有可显示笔记时，给出简洁空态和“创建笔记”入口。
class NotesEmptyState extends StatelessWidget {
  const NotesEmptyState({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.square_pencil,
            size: 38,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(l10n.noNotesYet),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(CupertinoIcons.add),
            label: Text(l10n.createNote),
          ),
        ],
      ),
    );
  }
}
