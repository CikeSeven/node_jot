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

class _NotesPageState extends ConsumerState<NotesPage>
    with SingleTickerProviderStateMixin {
  static const Duration _deleteUndoSnackDuration = Duration(seconds: 4);
  static const Duration _restoreHintDuration = Duration(seconds: 2);
  static const Duration _searchDebounceDuration = Duration(milliseconds: 200);
  static const Duration _searchMorphDuration = Duration(milliseconds: 280);

  final Set<String> _selectedNoteIds = <String>{};
  final Set<String> _optimisticHiddenNoteIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _listSearchFieldKey = GlobalKey();
  final GlobalKey _topSearchFieldKey = GlobalKey();
  Timer? _searchDebounceTimer;
  OverlayEntry? _searchMorphOverlay;
  Rect? _cachedListSearchRect;
  late final AnimationController _searchMorphController;
  String _searchInput = '';
  String _effectiveSearchKeyword = '';
  bool _isSearchMode = false;
  bool _isSearchAnimating = false;
  bool _isSearchMorphEntering = false;

  bool get _isSelectionMode => _selectedNoteIds.isNotEmpty;
  bool get _showTopSearchField => _isSearchMode && !_isSearchAnimating;
  bool get _showHeaderSection => !_isSearchMode && !_isSearchAnimating;

  @override
  void initState() {
    super.initState();
    _searchMorphController = AnimationController(
      vsync: this,
      duration: _searchMorphDuration,
    )..addListener(() {
      _searchMorphOverlay?.markNeedsBuild();
    });
  }

  @override
  void dispose() {
    _searchMorphOverlay?.remove();
    _searchMorphOverlay = null;
    _searchMorphController.dispose();
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
      if (forceSelect && _isSearchMode) {
        _isSearchMode = false;
        _isSearchAnimating = false;
        _searchFocusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      }
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

  bool get _searchActivationEnabled => !_isSelectionMode && !_isSearchAnimating;

  Future<void> _activateSearchMode() async {
    if (!_searchActivationEnabled || _isSearchMode) {
      return;
    }
    await _runSearchMorph(enter: true);
  }

  Future<void> _deactivateSearchMode() async {
    if (_isSearchAnimating || !_isSearchMode) {
      return;
    }
    await _runSearchMorph(enter: false);
  }

  Future<void> _runSearchMorph({required bool enter}) async {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    final beginRect = _rectFromKey(
      enter ? _listSearchFieldKey : _topSearchFieldKey,
    );
    if (enter && beginRect != null) {
      _cachedListSearchRect = beginRect;
    }
    final endRect =
        enter
            ? _rectFromKey(_topSearchFieldKey)
            : (_cachedListSearchRect ?? _rectFromKey(_listSearchFieldKey));
    if (beginRect == null || endRect == null) {
      setState(() {
        _isSearchMode = enter;
        _isSearchAnimating = false;
        _isSearchMorphEntering = false;
      });
      if (enter) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      }
      return;
    }

    setState(() {
      _isSearchAnimating = true;
      _isSearchMorphEntering = enter;
    });
    if (!mounted) {
      return;
    }

    _showSearchMorphOverlay(beginRect, endRect);
    _searchMorphController.value = 0;
    var completed = false;
    try {
      await _searchMorphController.forward();
      completed = true;
    } finally {
      if (!completed) {
        _removeSearchMorphOverlay();
        if (mounted) {
          setState(() {
            _isSearchAnimating = false;
            _isSearchMorphEntering = false;
          });
        }
      }
    }
    if (!mounted) {
      _removeSearchMorphOverlay();
      return;
    }

    setState(() {
      _isSearchMode = enter;
      _isSearchAnimating = false;
      _isSearchMorphEntering = false;
    });
    await Future<void>.delayed(Duration.zero);
    _removeSearchMorphOverlay();

    if (enter) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    } else {
      _searchFocusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  Rect? _rectFromKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return null;
    }
    final object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) {
      return null;
    }
    final topLeft = object.localToGlobal(Offset.zero);
    return topLeft & object.size;
  }

  void _showSearchMorphOverlay(Rect begin, Rect end) {
    _removeSearchMorphOverlay();
    final overlay = Overlay.of(context, rootOverlay: true);
    _searchMorphOverlay = OverlayEntry(
      builder: (context) {
        final t = Curves.easeOutCubic.transform(_searchMorphController.value);
        final rect = Rect.lerp(begin, end, t)!;
        return Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: IgnorePointer(child: _buildMorphSearchGhost(context)),
            ),
          ],
        );
      },
    );
    overlay.insert(_searchMorphOverlay!);
  }

  void _removeSearchMorphOverlay() {
    _searchMorphOverlay?.remove();
    _searchMorphOverlay = null;
  }

  Widget _buildMorphSearchGhost(BuildContext context) {
    final displayedText = _searchInput.trim();
    final hasText = displayedText.isNotEmpty;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color:
              Theme.of(context).inputDecorationTheme.fillColor ??
              Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.22),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.search,
              size: 18,
              color: textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasText ? displayedText : context.l10n.searchNotesHint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    hasText
                        ? textTheme.bodyLarge
                        : textTheme.bodyMedium?.copyWith(
                          color: textTheme.bodySmall?.color?.withValues(
                            alpha: 0.8,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSearchField() {
    final l10n = context.l10n;
    final hasText = _searchInput.isNotEmpty;
    return Container(
      key: _topSearchFieldKey,
      height: 48,
      alignment: Alignment.center,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.searchNotesHint,
          prefixIcon: const Icon(CupertinoIcons.search),
          suffixIcon: SizedBox(
            width: hasText ? 84 : 44,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasText)
                  IconButton(
                    tooltip: l10n.cancel,
                    onPressed: _clearSearch,
                    icon: const Icon(CupertinoIcons.clear_circled_solid),
                  ),
                IconButton(
                  tooltip: l10n.cancel,
                  onPressed: _deactivateSearchMode,
                  icon: const Icon(CupertinoIcons.xmark_circle_fill),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSearchLayer() {
    return IgnorePointer(
      ignoring: !_showTopSearchField,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            0,
          ),
          child: AnimatedOpacity(
            duration: _searchMorphDuration,
            curve: Curves.easeOutCubic,
            opacity: _showTopSearchField ? 1 : 0,
            child: _buildTopSearchField(),
          ),
        ),
      ),
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
            canPop: !(_isSelectionMode || _isSearchMode || _isSearchAnimating),
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) {
                return;
              }
              if (_isSearchMode || _isSearchAnimating) {
                unawaited(_deactivateSearchMode());
                return;
              }
              if (_isSelectionMode) {
                _clearSelection();
              }
            },
            child: Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) {
                  return KeyEventResult.ignored;
                }
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  if (_isSearchMode || _isSearchAnimating) {
                    unawaited(_deactivateSearchMode());
                    return KeyEventResult.handled;
                  }
                  if (_isSelectionMode) {
                    _clearSelection();
                    return KeyEventResult.handled;
                  }
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

                      final showListSearchRow =
                          _isSearchAnimating ? !_isSearchMorphEntering : !_isSearchMode;
                      final hideListSearchFieldVisual =
                          _isSearchMode || _isSearchAnimating;

                      return Column(
                        children: [
                          // 区块一：顶部头部（标题 + 页面操作）。
                          AnimatedOpacity(
                            duration: _searchMorphDuration,
                            curve: Curves.easeOutCubic,
                            opacity: _showHeaderSection ? 1 : 0,
                            child: IgnorePointer(
                              ignoring: !_showHeaderSection,
                              child: NotesHeaderSection(
                                isSelectionMode: _isSelectionMode,
                                selectedCount: _selectedNoteIds.length,
                                onCancelSelection: _clearSelection,
                                onArchiveSelected:
                                    () => _archiveSelected(services, l10n),
                                onDeleteSelected:
                                    () => _deleteSelected(services, l10n),
                                onOpenArchived:
                                    () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const ArchivedNotesPage(),
                                      ),
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s),
                          // 区块二：主列表区域（含标题行、空态、笔记卡片）。
                          NotesListSection(
                            searchFieldKey: _listSearchFieldKey,
                            searchPreviewText: _searchInput,
                            showSearchRow: showListSearchRow,
                            animateSearchRow: true,
                            hideSearchFieldVisual: hideListSearchFieldVisual,
                            searchEnabled: _searchActivationEnabled,
                            onActivateSearchMode: _activateSearchMode,
                            notes: notes,
                            selectedNoteIds: _selectedNoteIds,
                            isSelectionMode: _isSelectionMode,
                            listBottomOffset: listBottomOffset,
                            desktopContextMenuEnabled: desktopContextMenuEnabled,
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
          // 顶部搜索层：进入搜索后承载可编辑输入框，并在进入/退出时作为位移动画目标位。
          _buildTopSearchLayer(),
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
