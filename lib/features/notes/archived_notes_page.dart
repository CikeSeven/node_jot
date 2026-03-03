import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/app_services.dart';
import '../../core/utils/note_doc_codec.dart';
import '../../core/utils/relative_time_formatter.dart';
import '../../data/isar/collections/note_entity.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/ios_frosted_panel.dart';
import 'note_editor_page.dart';

/// 归档笔记页。
///
/// 展示所有已归档且未删除的笔记，并支持左滑取消归档。
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
              // UI 兜底过滤：确保仅展示“未删除且已归档”的笔记。
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
                    background: _SwipeActionBackground(
                      label: l10n.unarchive,
                      icon: CupertinoIcons.tray_arrow_up_fill,
                      color: const Color(0xFF5EA385),
                    ),
                    onDismissed: (_) async {
                      await services.syncEngine.unarchiveLocalNote(note.noteId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.noteUnarchived)),
                        );
                      }
                    },
                    child: _ArchivedNoteCard(
                      note: note,
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => NoteEditorPage(noteId: note.noteId),
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

class _ArchivedNoteCard extends StatelessWidget {
  const _ArchivedNoteCard({required this.note, required this.onTap});

  final NoteEntity note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final displayTitle =
        (note.displayTitleCache ?? '').trim().isEmpty
            ? note.title
            : note.displayTitleCache!;
    final previewText =
        (note.previewTextCache ?? '').trim().isNotEmpty
            ? note.previewTextCache!.trim()
            : NoteDocCodec.extractPreviewText(note.contentMd).trim();
    return SizedBox(
      width: double.infinity,
      child: IosFrostedPanel(
        radius: 16,
        blur: 14,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 17),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (previewText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    previewText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 9),
                ] else
                  const SizedBox(height: 6),
                Text(
                  RelativeTimeFormatter.formatUpdatedAt(
                    updatedAt: note.updatedAt,
                    now: DateTime.now(),
                    l10n: l10n,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
