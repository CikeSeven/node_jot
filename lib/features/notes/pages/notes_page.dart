import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/app_services.dart';
import '../../../data/isar/collections/note_entity.dart';
import '../../../l10n/app_localizations.dart';
import '../note_editor_page.dart';
import '../sections/notes_header_section.dart';
import '../sections/notes_list_section.dart';
import 'archived_notes_page.dart';

/// 笔记首页。
///
/// 页面职责：
/// - 管理多选状态、删除撤销、归档交互；
/// - 订阅活跃笔记流并做界面过滤；
/// - 组装顶部头部区块、列表区块和悬浮新建按钮。
class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  static const Duration _deleteUndoSnackDuration = Duration(seconds: 4);
  static const Duration _restoreHintDuration = Duration(seconds: 2);
  static const Duration _searchDebounceDuration = Duration(milliseconds: 200);

  final Set<String> _selectedNoteIds = <String>{};
  final Set<String> _optimisticHiddenNoteIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;
  String _searchInput = '';
  String _effectiveSearchKeyword = '';

  bool get _isSelectionMode => _selectedNoteIds.isNotEmpty;

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

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
    _showFloatingSnackBar(message: l10n.selectedArchived(selectedIds.length));
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
            content: Text(l10n.deleteSelectedConfirmMessage(selectedIds.length)),
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
    _showFloatingSnackBar(message: l10n.selectedRestored(noteIds.length));
  }

  void _openEditor([String? noteId]) {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(
      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => NoteEditorPage(noteId: noteId),
            ),
          )
          .then((_) {
            if (!mounted) {
              return;
            }
            _searchFocusNode.unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          }),
    );
  }

  void _onSearchChanged(String value) {
    if (_searchInput != value) {
      setState(() {
        _searchInput = value;
      });
    }

    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      final normalized = _searchInput.trim();
      if (normalized == _effectiveSearchKeyword) {
        return;
      }
      setState(() {
        _effectiveSearchKeyword = normalized;
      });
    });
  }

  void _clearSearch() {
    if (_searchInput.isEmpty && _effectiveSearchKeyword.isEmpty) {
      return;
    }
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchInput = '';
      _effectiveSearchKeyword = '';
    });
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
        margin: EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          bottomMargin,
        ),
        duration: _deleteUndoSnackDuration,
        content: Row(
          children: [
            Expanded(child: Text(deletedMessage)),
            TextButton(
              onPressed: () async {
                messenger.hideCurrentSnackBar();
                await onUndo();
                if (mounted) {
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

  /// 计算浮动提示距离底部导航栏的安全抬升。
  double _snackBottomMargin() {
    final platform = Theme.of(context).platform;
    final useSideRail =
        platform == TargetPlatform.windows || platform == TargetPlatform.macOS;
    if (useSideRail) {
      return 16 + MediaQuery.paddingOf(context).bottom;
    }
    return 104 + MediaQuery.paddingOf(context).bottom;
  }

  void _showFloatingSnackBar({required String message, Duration? duration}) {
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
      resizeToAvoidBottomInset: false,
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
                    stream: services.noteRepository.watchActiveNotesByKeyword(
                      _effectiveSearchKeyword,
                    ),
                    builder: (context, snapshot) {
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
                                    !_optimisticHiddenNoteIds.contains(
                                      note.noteId,
                                    ),
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
                          // 区块一：顶部头部（标题 + 页面操作）。
                          NotesHeaderSection(
                            isSelectionMode: _isSelectionMode,
                            selectedCount: _selectedNoteIds.length,
                            onCancelSelection: _clearSelection,
                            onArchiveSelected: () => _archiveSelected(services, l10n),
                            onDeleteSelected: () => _deleteSelected(services, l10n),
                            onOpenArchived:
                                () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const ArchivedNotesPage(),
                                  ),
                                ),
                          ),
                          const SizedBox(height: AppSpacing.s),
                          // 区块二：主列表区域（含标题行、空态、笔记卡片）。
                          NotesListSection(
                            searchController: _searchController,
                            searchFocusNode: _searchFocusNode,
                            notes: notes,
                            searchText: _searchInput,
                            selectedNoteIds: _selectedNoteIds,
                            isSelectionMode: _isSelectionMode,
                            listBottomOffset: listBottomOffset,
                            desktopContextMenuEnabled: desktopContextMenuEnabled,
                            onSearchChanged: _onSearchChanged,
                            onClearSearch: _clearSearch,
                            onCreate: _openEditor,
                            onOpenEditor: _openEditor,
                            onToggleSelection:
                                (noteId, forceSelect) =>
                                    _toggleSelection(
                                      noteId,
                                      forceSelect: forceSelect,
                                    ),
                            onShowContextMenu:
                                (globalPosition, note) => _showNoteContextMenu(
                                  globalPosition: globalPosition,
                                  note: note,
                                  services: services,
                                  l10n: l10n,
                                ),
                            onArchiveBySwipe: (note) async {
                              await services.syncEngine.archiveLocalNote(
                                note.noteId,
                              );
                              if (context.mounted) {
                                _showFloatingSnackBar(message: l10n.noteArchived);
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          // 区块三：悬浮新建按钮（多选模式隐藏）。
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
