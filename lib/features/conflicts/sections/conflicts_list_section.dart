import 'package:flutter/material.dart';

import '../../../data/isar/collections/note_entity.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/conflict_note_tile.dart';

/// 冲突列表区块。
///
/// 职责：
/// - 处理空状态；
/// - 渲染冲突条目列表；
/// - 将条目点击回调透传给上层页面处理导航。
class ConflictsListSection extends StatelessWidget {
  const ConflictsListSection({
    super.key,
    required this.conflicts,
    required this.onOpenNote,
  });

  final List<NoteEntity> conflicts;
  final ValueChanged<NoteEntity> onOpenNote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (conflicts.isEmpty) {
      return Center(child: Text(l10n.noConflictNotes));
    }

    return ListView.separated(
      itemCount: conflicts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final note = conflicts[index];
        return ConflictNoteTile(
          note: note,
          onTap: () => onOpenNote(note),
        );
      },
    );
  }
}
