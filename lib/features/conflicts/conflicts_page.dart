import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../core/models/app_services.dart';
import '../../data/isar/collections/note_entity.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/ios_card_tile.dart';
import '../../ui/widgets/ios_frosted_panel.dart';
import '../notes/note_editor_page.dart';

/// 冲突副本列表页。
///
/// 展示无法自动快进合并时生成的冲突笔记。
class ConflictsPage extends ConsumerWidget {
  const ConflictsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final services = ref.watch(appServicesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.conflicts)),
      body: Container(
        // 页面背景层。
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<NoteEntity>>(
            stream: services.noteRepository.watchConflictNotes(),
            builder: (context, snapshot) {
              final conflicts = snapshot.data ?? const <NoteEntity>[];
              if (conflicts.isEmpty) {
                // 空态：当前没有冲突副本。
                return Center(child: Text(l10n.noConflictNotes));
              }

              // 冲突列表：每项可跳转进入编辑处理。
              return ListView.separated(
                itemCount: conflicts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final note = conflicts[index];
                  return IosFrostedPanel(
                    radius: 16,
                    child: IosCardTile(
                      title: note.title,
                      subtitle: l10n.updatedAtLabel(
                        DateFormat(
                          'yyyy-MM-dd HH:mm',
                        ).format(note.updatedAt.toLocal()),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => NoteEditorPage(noteId: note.noteId),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
