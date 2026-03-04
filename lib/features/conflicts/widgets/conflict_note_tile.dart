import 'package:flutter/material.dart';

import '../../../core/utils/relative_time_formatter.dart';
import '../../../data/isar/collections/note_entity.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/widgets/ios_card_tile.dart';
import '../../../ui/widgets/ios_frosted_panel.dart';

/// 冲突笔记列表项。
///
/// 布局结构：
/// - 标题；
/// - 更新时间；
/// - 右侧冲突标签。
class ConflictNoteTile extends StatelessWidget {
  const ConflictNoteTile({
    super.key,
    required this.note,
    required this.onTap,
  });

  final NoteEntity note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final displayTitle =
        (note.displayTitleCache ?? '').trim().isEmpty
            ? note.title
            : note.displayTitleCache!;

    return IosFrostedPanel(
      radius: 16,
      child: IosCardTile(
        title: displayTitle,
        subtitle: l10n.updatedAtLabel(
          RelativeTimeFormatter.formatUpdatedAt(
            updatedAt: note.updatedAt,
            now: DateTime.now(),
            l10n: l10n,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3D9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            l10n.noteConflictTag,
            style: const TextStyle(
              color: Color(0xFFB54708),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
