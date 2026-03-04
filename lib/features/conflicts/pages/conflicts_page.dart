import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/models/app_services.dart';
import '../../../data/isar/collections/note_entity.dart';
import '../../../l10n/app_localizations.dart';
import '../../notes/note_editor_page.dart';
import '../sections/conflicts_list_section.dart';

/// 冲突副本列表页。
///
/// 页面职责：
/// - 订阅冲突笔记流；
/// - 展示冲突列表区块；
/// - 跳转到笔记编辑页处理冲突内容。
class ConflictsPage extends ConsumerWidget {
  const ConflictsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final services = ref.watch(appServicesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.conflicts)),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.pageBackground(Theme.of(context).brightness),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<NoteEntity>>(
            stream: services.noteRepository.watchConflictNotes(),
            builder: (context, snapshot) {
              final conflicts = snapshot.data ?? const <NoteEntity>[];
              return ConflictsListSection(
                conflicts: conflicts,
                onOpenNote:
                    (note) => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NoteEditorPage(noteId: note.noteId),
                      ),
                    ),
              );
            },
          ),
        ),
      ),
    );
  }
}
