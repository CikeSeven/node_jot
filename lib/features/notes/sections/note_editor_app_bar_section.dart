import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// 编辑页顶部应用栏区块。
///
/// 布局元素：
/// - 返回按钮；
/// - 标题；
/// - 删除按钮。
class NoteEditorAppBarSection extends StatelessWidget
    implements PreferredSizeWidget {
  const NoteEditorAppBarSection({
    super.key,
    required this.onBack,
    required this.onManageCategories,
    required this.onDelete,
  });

  final VoidCallback onBack;
  final VoidCallback onManageCategories;
  final VoidCallback onDelete;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppBar(
      title: Text(
        l10n.noteTitle,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: onBack,
        icon: const Icon(CupertinoIcons.chevron_back),
      ),
      actions: [
        IconButton(
          tooltip: l10n.noteCategories,
          onPressed: onManageCategories,
          icon: const Icon(CupertinoIcons.tag),
        ),
        IconButton(
          tooltip: l10n.delete,
          onPressed: onDelete,
          icon: Icon(
            CupertinoIcons.delete,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}
