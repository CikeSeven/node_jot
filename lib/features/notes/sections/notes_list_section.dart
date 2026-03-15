import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../data/isar/collections/note_entity.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/note_category_filter_bar.dart';
import '../widgets/note_card.dart';
import '../widgets/notes_empty_state.dart';
import '../widgets/swipe_action_background.dart';

/// 笔记页主列表区块。
///
/// 布局职责：
/// - 顶部搜索与分类筛选；
/// - 空状态展示；
/// - 普通卡片列表；
/// - 非多选模式下支持左滑归档。
class NotesListSection extends StatelessWidget {
  static const Duration _searchRowAnimationDuration = Duration(
    milliseconds: 280,
  );
  static const double _archiveSwipeThreshold = 0.82;

  const NotesListSection({
    super.key,
    required this.searchFieldKey,
    required this.searchPreviewText,
    required this.showSearchRow,
    required this.animateSearchRow,
    required this.hideSearchFieldVisual,
    required this.searchEnabled,
    required this.onActivateSearchMode,
    required this.categoryFilters,
    required this.selectedCategoryFilterKeys,
    required this.onToggleCategoryFilter,
    required this.onClearCategoryFilters,
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

  final GlobalKey searchFieldKey;
  final String searchPreviewText;
  final bool showSearchRow;
  final bool animateSearchRow;
  final bool hideSearchFieldVisual;
  final bool searchEnabled;
  final VoidCallback onActivateSearchMode;
  final List<String> categoryFilters;
  final Set<String> selectedCategoryFilterKeys;
  final void Function(String category, bool selected) onToggleCategoryFilter;
  final VoidCallback onClearCategoryFilters;
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
    final itemCount = notes.isEmpty ? 3 : notes.length + 2;
    return Expanded(
      child: ListView.separated(
        key: const PageStorageKey<String>('notes_list'),
        padding: EdgeInsets.only(bottom: listBottomOffset),
        itemCount: itemCount,
        separatorBuilder: (context, index) {
          if (index == 0 && !showSearchRow) {
            return const SizedBox.shrink();
          }
          return const SizedBox(height: 8);
        },
        itemBuilder: (context, index) {
          // 区块一：搜索框（列表顶部，随列表滚动）。
          if (index == 0) {
            final hintStyle = Theme.of(context).textTheme.bodyMedium;
            final textStyle = Theme.of(context).textTheme.bodyLarge;
            final displayedText = searchPreviewText.trim();
            final hasText = displayedText.isNotEmpty;
            final targetHeight = showSearchRow ? 48.0 : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: AnimatedContainer(
                key: searchFieldKey,
                duration:
                    animateSearchRow
                        ? _searchRowAnimationDuration
                        : Duration.zero,
                curve: Curves.easeOutCubic,
                height: targetHeight,
                child: ClipRect(
                  child: Opacity(
                    opacity: hideSearchFieldVisual ? 0 : 1,
                    child: AbsorbPointer(
                      absorbing: hideSearchFieldVisual || !showSearchRow,
                      child: GestureDetector(
                        onTap: searchEnabled ? onActivateSearchMode : null,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(
                                  context,
                                ).inputDecorationTheme.fillColor ??
                                Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  searchEnabled
                                      ? Theme.of(
                                        context,
                                      ).dividerColor.withValues(alpha: 0.22)
                                      : Theme.of(
                                        context,
                                      ).dividerColor.withValues(alpha: 0.1),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.search,
                                size: 18,
                                color:
                                    searchEnabled
                                        ? Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.color
                                        : Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color
                                            ?.withValues(alpha: 0.45),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  hasText
                                      ? displayedText
                                      : context.l10n.searchNotesHint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      hasText
                                          ? textStyle
                                          : hintStyle?.copyWith(
                                            color: hintStyle.color?.withValues(
                                              alpha: 0.8,
                                            ),
                                          ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          // 区块二：分类筛选栏（位于搜索框下方，随列表滚动）。
          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: NoteCategoryFilterBar(
                categories: categoryFilters,
                selectedCategoryKeys: selectedCategoryFilterKeys,
                onToggleCategory: onToggleCategoryFilter,
                onClearCategories: onClearCategoryFilters,
              ),
            );
          }

          // 区块三：空状态。
          if (notes.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: NotesEmptyState(onCreate: onCreate),
            );
          }

          // 区块四：普通笔记卡片。
          final note = notes[index - 2];
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
            dismissThresholds: const <DismissDirection, double>{
              DismissDirection.endToStart: _archiveSwipeThreshold,
            },
            background: SwipeActionBackground(
              label: context.l10n.archive,
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
