import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';

/// 笔记页顶部头部区块。
///
/// 布局职责：
/// - 左侧展示页面标题或多选计数；
/// - 右侧展示操作按钮（取消选择、归档、删除、归档列表入口）。
class NotesHeaderSection extends StatelessWidget {
  const NotesHeaderSection({
    super.key,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.onCancelSelection,
    required this.onArchiveSelected,
    required this.onDeleteSelected,
    required this.onOpenArchived,
  });

  final bool isSelectionMode;
  final int selectedCount;
  final VoidCallback onCancelSelection;
  final VoidCallback onArchiveSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onOpenArchived;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isSelectionMode
                  ? l10n.selectedCountLabel(selectedCount)
                  : 'NodeJot',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (isSelectionMode) ...[
            IconButton(
              tooltip: l10n.cancel,
              onPressed: onCancelSelection,
              icon: const Icon(CupertinoIcons.xmark),
            ),
            IconButton(
              tooltip: l10n.archive,
              onPressed: onArchiveSelected,
              icon: const Icon(CupertinoIcons.archivebox),
            ),
            IconButton(
              tooltip: l10n.delete,
              onPressed: onDeleteSelected,
              icon: Icon(
                CupertinoIcons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ] else
            IconButton(
              tooltip: l10n.archivedNotes,
              onPressed: onOpenArchived,
              icon: const Icon(CupertinoIcons.archivebox),
            ),
        ],
      ),
    );
  }
}
