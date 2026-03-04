import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/app_services.dart';
import '../../../data/isar/collections/note_entity.dart';
import '../../../l10n/app_localizations.dart';
import '../note_editor_page.dart';
import '../widgets/archived_note_card.dart';
import '../widgets/swipe_action_background.dart';

/// 归档笔记页。
///
/// 页面职责：
/// - 展示已归档且未删除的笔记；
/// - 提供左滑“取消归档”手势；
/// - 点击条目可进入编辑页。
class ArchivedNotesPage extends ConsumerWidget {
  const ArchivedNotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final services = ref.watch(appServicesProvider);
    final platform = Theme.of(context).platform;
    final useSideRail =
        platform == TargetPlatform.windows || platform == TargetPlatform.macOS;
    final listBottomOffset =
        useSideRail ? 16.0 : 112 + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.archivedNotes)),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.pageBackground(Theme.of(context).brightness),
        ),
        child: SafeArea(
          child: StreamBuilder<List<NoteEntity>>(
            stream: services.noteRepository.watchArchivedNotes(),
            builder: (context, snapshot) {
              final rawNotes = snapshot.data ?? const <NoteEntity>[];
              final notes =
                  rawNotes
                      .where(
                        (note) =>
                            note.deletedAt == null && note.archivedAt != null,
                      )
                      .toList(growable: false);
              if (notes.isEmpty) {
                return Center(child: Text(l10n.noArchivedNotes));
              }

              return ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.m,
                  AppSpacing.l,
                  listBottomOffset,
                ),
                itemCount: notes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return Dismissible(
                    key: ValueKey<String>('archived-${note.noteId}'),
                    direction: DismissDirection.endToStart,
                    background: SwipeActionBackground(
                      label: l10n.unarchive,
                      icon: CupertinoIcons.tray_arrow_up_fill,
                      color: const Color(0xFF5EA385),
                      horizontalMargin: 0,
                    ),
                    onDismissed: (_) async {
                      await services.syncEngine.unarchiveLocalNote(note.noteId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(l10n.noteUnarchived)));
                      }
                    },
                    child: ArchivedNoteCard(
                      note: note,
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => NoteEditorPage(noteId: note.noteId),
                            ),
                          ),
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
