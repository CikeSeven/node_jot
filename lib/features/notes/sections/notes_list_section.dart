import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../data/isar/collections/note_entity.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/note_card.dart';
import '../widgets/notes_empty_state.dart';
import '../widgets/swipe_action_background.dart';

/// 笔记页主列表区块。
///
/// 布局职责：
/// - 顶部列表标题行；
/// - 空状态展示；
/// - 普通卡片列表；
/// - 非多选模式下支持左滑归档。
class NotesListSection extends StatelessWidget {
  const NotesListSection({
    super.key,
    required this.notes,
    required this.selectedNoteIds,
    required this.isSelectionMode,
    required this.listBottomOffset,
    required this.desktopContextMenuEnabled,
    required this.onCreate,
    required this.onOpenEditor,
    required this.onToggleSelection,
    required this.onShowContextMenu,
    required this.onArchiveBySwipe,
  });

  final List<NoteEntity> notes;
  final Set<String> selectedNoteIds;
  final bool isSelectionMode;
  final double listBottomOffset;
  final bool desktopContextMenuEnabled;
  final VoidCallback onCreate;
  final ValueChanged<String?> onOpenEditor;
  final void Function(String noteId, bool forceSelect) onToggleSelection;
  final Future<void> Function(Offset globalPosition, NoteEntity note)
  onShowContextMenu;
  final Future<void> Function(NoteEntity note) onArchiveBySwipe;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Expanded(
      child: ListView.separated(
        key: const PageStorageKey<String>('notes_list'),
        padding: EdgeInsets.only(bottom: listBottomOffset),
        itemCount: notes.isEmpty ? 2 : notes.length + 1,
        separatorBuilder: (context, index) {
          return SizedBox(height: index == 0 ? 8 : 10);
        },
        itemBuilder: (context, index) {
          // 区块一：列表标题行（固定在列表第一项，随列表滚动）。
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.tabNotes,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    DateFormat('MMM d').format(DateTime.now()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          // 区块二：空状态。
          if (notes.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: NotesEmptyState(onCreate: onCreate),
            );
          }

          // 区块三：普通笔记卡片。
          final note = notes[index - 1];
          final selected = selectedNoteIds.contains(note.noteId);

          Widget card = Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
            child: NoteCard(
              note: note,
              selected: selected,
              onTap: () {
                if (isSelectionMode) {
                  onToggleSelection(note.noteId, false);
                  return;
                }
                onOpenEditor(note.noteId);
              },
              onLongPress: () => onToggleSelection(note.noteId, true),
            ),
          );

          // 桌面端右键上下文菜单，仅在非多选模式启用。
          if (!isSelectionMode && desktopContextMenuEnabled) {
            card = GestureDetector(
              behavior: HitTestBehavior.translucent,
              onSecondaryTapDown: (details) async {
                await onShowContextMenu(details.globalPosition, note);
              },
              child: card,
            );
          }

          // 多选模式下关闭滑动手势，避免与批量操作语义冲突。
          if (isSelectionMode) {
            return card;
          }

          return Dismissible(
            key: ValueKey<String>('active-${note.noteId}'),
            direction: DismissDirection.endToStart,
            background: SwipeActionBackground(
              label: l10n.archive,
              icon: CupertinoIcons.archivebox_fill,
              color: const Color(0xFF9C6BD8),
            ),
            onDismissed: (_) async {
              await onArchiveBySwipe(note);
            },
            child: card,
          );
        },
      ),
    );
  }
}
