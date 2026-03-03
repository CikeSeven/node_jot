import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/app_services.dart';
import '../../core/utils/note_doc_codec.dart';
import '../../core/utils/relative_time_formatter.dart';
import '../../data/isar/collections/note_entity.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/ios_frosted_panel.dart';
import 'archived_notes_page.dart';
import 'note_editor_page.dart';

/// 笔记首页。
///
/// 支持：
/// - 左滑单条归档；
/// - 长按进入多选模式；
/// - 顶部图标批量归档/删除；
/// - 删除后可在提示中撤销。
class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  static const Duration _deleteUndoSnackDuration = Duration(seconds: 4);
  static const Duration _restoreHintDuration = Duration(seconds: 2);
  final Set<String> _selectedNoteIds = <String>{};
  final Set<String> _optimisticHiddenNoteIds = <String>{};

  bool get _isSelectionMode => _selectedNoteIds.isNotEmpty;

  void _clearSelection() {
    if (_selectedNoteIds.isEmpty) {
      return;
    }
    setState(_selectedNoteIds.clear);
  }

  void _toggleSelection(String noteId, {bool forceSelect = false}) {
    setState(() {
      if (forceSelect) {
        _selectedNoteIds.add(noteId);
        return;
      }

      if (_selectedNoteIds.contains(noteId)) {
        _selectedNoteIds.remove(noteId);
      } else {
        _selectedNoteIds.add(noteId);
      }
    });
  }

  Future<void> _archiveSelected(
    AppServices services,
    AppLocalizations l10n,
  ) async {
    if (_selectedNoteIds.isEmpty) {
      return;
    }
    final selectedIds = _selectedNoteIds.toList(growable: false);
    _clearSelection();
    for (final noteId in selectedIds) {
      await services.syncEngine.archiveLocalNote(noteId);
    }
    if (!mounted) {
      return;
    }
    _showFloatingSnackBar(
      message: l10n.selectedArchived(selectedIds.length),
    );
  }

  Future<void> _deleteSelected(
    AppServices services,
    AppLocalizations l10n,
  ) async {
    if (_selectedNoteIds.isEmpty) {
      return;
    }
    final selectedIds = _selectedNoteIds.toList(growable: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(l10n.delete),
            content: Text(
              l10n.deleteSelectedConfirmMessage(selectedIds.length),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }

    _clearSelection();
    setState(() {
      _optimisticHiddenNoteIds.addAll(selectedIds);
    });
    for (final noteId in selectedIds) {
      await services.syncEngine.deleteLocalNote(noteId);
    }
    if (!mounted) {
      return;
    }

    _showDeleteUndoSnackBar(
      deletedMessage: l10n.selectedDeleted(selectedIds.length),
      restoredMessage: l10n.selectedRestored(selectedIds.length),
      undoLabel: l10n.undo,
      onUndo: () async {
        if (mounted) {
          setState(() {
            _optimisticHiddenNoteIds.removeAll(selectedIds);
          });
        }
        await _undoDeleteBatch(selectedIds, services, l10n);
      },
    );
  }

  Future<void> _undoDeleteBatch(
    List<String> noteIds,
    AppServices services,
    AppLocalizations l10n,
  ) async {
    for (final noteId in noteIds) {
      await services.syncEngine.restoreDeletedLocalNote(noteId);
    }
    if (!mounted) {
      return;
    }
    setState(() {});
    _showFloatingSnackBar(
      message: l10n.selectedRestored(noteIds.length),
    );
  }

  void _openEditor([String? noteId]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteEditorPage(noteId: noteId)),
    );
  }

  Future<void> _archiveSingleNote({
    required String noteId,
    required AppServices services,
    required AppLocalizations l10n,
  }) async {
    await services.syncEngine.archiveLocalNote(noteId);
    if (!mounted) {
      return;
    }
    _showFloatingSnackBar(message: l10n.selectedArchived(1));
  }

  Future<void> _deleteSingleNoteWithUndo({
    required String noteId,
    required AppServices services,
    required AppLocalizations l10n,
  }) async {
    setState(() {
      _optimisticHiddenNoteIds.add(noteId);
    });
    await services.syncEngine.deleteLocalNote(noteId);
    if (!mounted) {
      return;
    }
    _showDeleteUndoSnackBar(
      deletedMessage: l10n.selectedDeleted(1),
      restoredMessage: l10n.selectedRestored(1),
      undoLabel: l10n.undo,
      onUndo: () async {
        if (mounted) {
          setState(() {
            _optimisticHiddenNoteIds.remove(noteId);
          });
        }
        await services.syncEngine.restoreDeletedLocalNote(noteId);
      },
    );
  }

  void _showDeleteUndoSnackBar({
    required String deletedMessage,
    required String restoredMessage,
    required String undoLabel,
    required Future<void> Function() onUndo,
  }) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final undoColor = Theme.of(context).colorScheme.primary;
    final bottomMargin = _snackBottomMargin();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(AppSpacing.l, 0, AppSpacing.l, bottomMargin),
        duration: _deleteUndoSnackDuration,
        content: Row(
          children: [
            Expanded(child: Text(deletedMessage)),
            TextButton(
              onPressed: () async {
                messenger.hideCurrentSnackBar();
                await onUndo();
                if (mounted) {
                  // 某些设备上 Isar 流在 restore 后不会立刻重建列表，
                  // 这里主动触发一次页面重建，保证撤销后笔记立即可见。
                  setState(() {});
                }
                messenger.showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.fromLTRB(
                      AppSpacing.l,
                      0,
                      AppSpacing.l,
                      bottomMargin,
                    ),
                    duration: _restoreHintDuration,
                    content: Text(restoredMessage),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: undoColor,
                padding: EdgeInsets.zero,
                minimumSize: const Size(40, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(undoLabel),
            ),
          ],
        ),
      ),
    );
  }

  /// 计算 SnackBar 距离底部的抬升量，确保显示在底部导航栏之上。
  double _snackBottomMargin() {
    final platform = Theme.of(context).platform;
    final useSideRail =
        platform == TargetPlatform.windows || platform == TargetPlatform.macOS;
    if (useSideRail) {
      return 16 + MediaQuery.paddingOf(context).bottom;
    }
    // 手机端底栏高度约 76 + 安全区与呼吸间距，额外加一点避免视觉贴边。
    return 104 + MediaQuery.paddingOf(context).bottom;
  }

  void _showFloatingSnackBar({
    required String message,
    Duration? duration,
  }) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          _snackBottomMargin(),
        ),
        duration: duration ?? const Duration(seconds: 2),
        content: Text(message),
      ),
    );
  }

  Future<void> _showNoteContextMenu({
    required BuildContext context,
    required Offset globalPosition,
    required NoteEntity note,
    required AppServices services,
    required AppLocalizations l10n,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<_NoteContextAction>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<_NoteContextAction>(
          value: _NoteContextAction.archive,
          child: Row(
            children: [
              const Icon(CupertinoIcons.archivebox, size: 18),
              const SizedBox(width: 8),
              Text(l10n.archive),
            ],
          ),
        ),
        PopupMenuItem<_NoteContextAction>(
          value: _NoteContextAction.delete,
          child: Row(
            children: [
              Icon(
                CupertinoIcons.delete,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );

    if (selected == null) {
      return;
    }
    if (selected == _NoteContextAction.archive) {
      await _archiveSingleNote(
        noteId: note.noteId,
        services: services,
        l10n: l10n,
      );
      return;
    }
    await _deleteSingleNoteWithUndo(
      noteId: note.noteId,
      services: services,
      l10n: l10n,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final services = ref.watch(appServicesProvider);
    final platform = Theme.of(context).platform;
    final useSideRail =
        platform == TargetPlatform.windows || platform == TargetPlatform.macOS;
    final desktopContextMenuEnabled =
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
    final fabBottomOffset =
        useSideRail ? 16.0 : 84 + MediaQuery.paddingOf(context).bottom;
    final listBottomOffset =
        useSideRail ? 16.0 : 112 + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        children: [
          PopScope(
            canPop: !_isSelectionMode,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && _isSelectionMode) {
                _clearSelection();
              }
            },
            child: Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) {
                  return KeyEventResult.ignored;
                }
                if (event.logicalKey == LogicalKeyboardKey.escape &&
                    _isSelectionMode) {
                  _clearSelection();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.pageBackground(Theme.of(context).brightness),
                ),
                child: SafeArea(
                  child: StreamBuilder<List<NoteEntity>>(
                    stream: services.noteRepository.watchActiveNotes(),
                    builder: (context, snapshot) {
                  // UI 侧再做一次兜底过滤，避免极端情况下 watch 流延迟导致的脏展示。
                  final rawNotes = snapshot.data ?? const <NoteEntity>[];
                  final activeIds =
                      rawNotes
                          .where(
                            (note) =>
                                note.deletedAt == null &&
                                note.archivedAt == null,
                          )
                          .map((note) => note.noteId)
                          .toSet();
                  final notes =
                      rawNotes
                          .where(
                            (note) =>
                                note.deletedAt == null &&
                                note.archivedAt == null &&
                                !_optimisticHiddenNoteIds.contains(note.noteId),
                          )
                          .toList(growable: false);
                  final visibleIds = notes.map((e) => e.noteId).toSet();
                  if (_selectedNoteIds.any((id) => !visibleIds.contains(id))) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _selectedNoteIds.removeWhere(
                          (id) => !visibleIds.contains(id),
                        );
                      });
                    });
                  }
                  if (_optimisticHiddenNoteIds.any(
                    (id) => !activeIds.contains(id),
                  )) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _optimisticHiddenNoteIds.removeWhere(
                          (id) => !activeIds.contains(id),
                        );
                      });
                    });
                  }

                  return Column(
                    children: [
                      Padding(
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
                                _isSelectionMode
                                    ? l10n.selectedCountLabel(
                                      _selectedNoteIds.length,
                                    )
                                    : 'NodeJot',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (_isSelectionMode) ...[
                              IconButton(
                                tooltip: l10n.cancel,
                                onPressed: _clearSelection,
                                icon: const Icon(CupertinoIcons.xmark),
                              ),
                              IconButton(
                                tooltip: l10n.archive,
                                onPressed:
                                    () => _archiveSelected(services, l10n),
                                icon: const Icon(CupertinoIcons.archivebox),
                              ),
                              IconButton(
                                tooltip: l10n.delete,
                                onPressed:
                                    () => _deleteSelected(services, l10n),
                                icon: Icon(
                                  CupertinoIcons.delete,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ] else
                              IconButton(
                                tooltip: l10n.archivedNotes,
                                onPressed:
                                    () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder:
                                            (_) => const ArchivedNotesPage(),
                                      ),
                                    ),
                                icon: const Icon(CupertinoIcons.archivebox),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      Expanded(
                        child: ListView.separated(
                          key: const PageStorageKey<String>('notes_list'),
                          padding: EdgeInsets.only(bottom: listBottomOffset),
                          itemCount: notes.isEmpty ? 2 : notes.length + 1,
                          separatorBuilder: (context, index) {
                            return SizedBox(height: index == 0 ? 8 : 10);
                          },
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.l,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l10n.tabNotes,
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'MMM d',
                                      ).format(DateTime.now()),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (notes.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.l,
                                ),
                                child: _EmptyState(onCreate: _openEditor),
                              );
                            }

                            final note = notes[index - 1];
                            final selected = _selectedNoteIds.contains(
                              note.noteId,
                            );
                            Widget card = Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.l,
                              ),
                              child: _NoteCard(
                                note: note,
                                selected: selected,
                                onTap: () {
                                  if (_isSelectionMode) {
                                    _toggleSelection(note.noteId);
                                    return;
                                  }
                                  _openEditor(note.noteId);
                                },
                                onLongPress:
                                    () => _toggleSelection(
                                      note.noteId,
                                      forceSelect: true,
                                    ),
                              ),
                            );

                            if (!_isSelectionMode &&
                                desktopContextMenuEnabled) {
                              card = GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onSecondaryTapDown: (details) async {
                                  await _showNoteContextMenu(
                                    context: context,
                                    globalPosition: details.globalPosition,
                                    note: note,
                                    services: services,
                                    l10n: l10n,
                                  );
                                },
                                child: card,
                              );
                            }

                            if (_isSelectionMode) {
                              return card;
                            }

                            return Dismissible(
                              key: ValueKey<String>('active-${note.noteId}'),
                              direction: DismissDirection.endToStart,
                              background: _SwipeActionBackground(
                                label: l10n.archive,
                                icon: CupertinoIcons.archivebox_fill,
                                color: const Color(0xFF9C6BD8),
                              ),
                              onDismissed: (_) async {
                                await services.syncEngine.archiveLocalNote(
                                  note.noteId,
                                );
                                if (context.mounted) {
                                  _showFloatingSnackBar(
                                    message: l10n.noteArchived,
                                  );
                                }
                              },
                              child: card,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
                  ),
                ),
              ),
            ),
          ),
          if (!_isSelectionMode)
            Positioned(
              right: AppSpacing.l,
              bottom: fabBottomOffset,
              child: FloatingActionButton(
                onPressed: _openEditor,
                child: const Icon(CupertinoIcons.add),
              ),
            ),
        ],
      ),
    );
  }
}

enum _NoteContextAction { archive, delete }

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
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
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

/// 笔记列表卡片。
class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onLongPress,
    required this.selected,
  });

  final NoteEntity note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final displayTitle =
        (note.displayTitleCache ?? '').trim().isEmpty
            ? note.title
            : note.displayTitleCache!;
    final previewText =
        (note.previewTextCache ?? '').trim().isNotEmpty
            ? note.previewTextCache!.trim()
            : NoteDocCodec.extractPreviewText(note.contentMd).trim();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border:
            selected
                ? Border.all(color: colorScheme.primary.withValues(alpha: 0.55))
                : null,
      ),
      child: IosFrostedPanel(
        radius: 16,
        blur: 14,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayTitle,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selected)
                      Icon(
                        CupertinoIcons.check_mark_circled_solid,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                  ],
                ),
                if (previewText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    previewText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      RelativeTimeFormatter.formatUpdatedAt(
                        updatedAt: note.updatedAt,
                        now: DateTime.now(),
                        l10n: l10n,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    if (note.isConflictCopy)
                      Container(
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 空状态视图。
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.square_pencil,
            size: 38,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(l10n.noNotesYet),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(CupertinoIcons.add),
            label: Text(l10n.createNote),
          ),
        ],
      ),
    );
  }
}
