import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/app_services.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/ios_frosted_panel.dart';

/// 编辑器显示模式。
enum _EditorViewMode { edit, preview }

/// 笔记编辑页。
///
/// 支持创建、编辑、保存、软删除与 Markdown 预览。
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, this.noteId});

  final String? noteId;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  static const _autosaveDelay = Duration(milliseconds: 300);
  static const _savedHintHold = Duration(seconds: 3);
  static const _deleteUndoSnackDuration = Duration(seconds: 4);
  static const _restoreHintDuration = Duration(seconds: 2);

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _editScrollController = ScrollController();
  final _previewScrollController = ScrollController();

  Timer? _autosaveTimer;
  Timer? _savedHintTimer;

  bool _loading = true;
  bool _isSaving = false;
  bool _hasPendingSave = false;
  bool _isBootstrapping = true;
  bool _muteDraftListener = false;
  bool _showSavedHintInBadge = false;
  bool _previewScrollInitialized = false;
  int? _expectedHeadRevision;
  String? _activeNoteId;
  String _lastSavedNormalizedTitle = '';
  String _lastSavedContent = '';
  _EditorViewMode _viewMode = _EditorViewMode.edit;

  bool get _isNewNoteSession => widget.noteId == null;

  @override
  void initState() {
    super.initState();
    _activeNoteId = widget.noteId;
    _titleController.addListener(_onDraftChanged);
    _contentController.addListener(_onDraftChanged);
    _load();
  }

  /// 根据 noteId 加载已有笔记内容；新建时预填“标题N”。
  Future<void> _load() async {
    final services = ref.read(appServicesProvider);

    if (_activeNoteId == null) {
      final nextTitleIndex = await services.noteRepository.getNextAutoTitleIndex();
      _setDraftSilently(title: '标题$nextTitleIndex', content: '');
      _lastSavedNormalizedTitle = _normalizedTitle(_titleController.text);
      _lastSavedContent = _contentController.text;
      _isBootstrapping = false;
      setState(() => _loading = false);
      return;
    }

    final note = await services.noteRepository.getByNoteId(_activeNoteId!);
    if (note != null) {
      _setDraftSilently(title: note.title, content: note.contentMd);
      _expectedHeadRevision = note.headRevision;
    }
    _lastSavedNormalizedTitle = _normalizedTitle(_titleController.text);
    _lastSavedContent = _contentController.text;
    _isBootstrapping = false;
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _setDraftSilently({String? title, String? content}) {
    _muteDraftListener = true;
    if (title != null) {
      _titleController.text = title;
    }
    if (content != null) {
      _contentController.text = content;
    }
    _muteDraftListener = false;
  }

  String _normalizedTitle(String input) {
    final trimmed = input.trim();
    return trimmed.isEmpty ? 'Untitled' : trimmed;
  }

  bool _hasUnsavedChanges() {
    return _normalizedTitle(_titleController.text) != _lastSavedNormalizedTitle ||
        _contentController.text != _lastSavedContent;
  }

  int get _contentCharCount => _contentController.text.characters.length;

  void _onDraftChanged() {
    if (_loading || _isBootstrapping || _muteDraftListener) {
      return;
    }
    if (mounted) {
      setState(() {});
    }
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, () {
      unawaited(_saveDraft());
    });
  }

  Future<void> _saveDraft() async {
    if (_loading || _isBootstrapping || !_hasUnsavedChanges()) {
      return;
    }
    if (_isSaving) {
      _hasPendingSave = true;
      return;
    }

    _isSaving = true;
    final services = ref.read(appServicesProvider);
    try {
      final result = await services.syncEngine.saveLocalNote(
        noteId: _activeNoteId,
        title: _titleController.text,
        contentMd: _contentController.text,
        expectedHeadRevision: _expectedHeadRevision,
      );
      _activeNoteId = result.note.noteId;
      _expectedHeadRevision = result.note.headRevision;
      _lastSavedNormalizedTitle = _normalizedTitle(result.note.title);
      _lastSavedContent = result.note.contentMd;
      if (result.hasInlineConflict && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.inlineConflictInserted)),
        );
      }
    } catch (_) {
      // 自动保存失败时静默等待下一次输入重试，避免频繁打断用户编辑。
    } finally {
      _isSaving = false;
      if (_hasPendingSave) {
        _hasPendingSave = false;
        await _saveDraft();
      }
    }
  }

  Future<void> _flushAutosave() async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    await _saveDraft();
  }

  Future<void> _cleanupNewNoteOnExit() async {
    if (!_isNewNoteSession) {
      return;
    }
    final noteId = _activeNoteId;
    if (noteId == null) {
      return;
    }
    if (_contentController.text.trim().isNotEmpty) {
      return;
    }

    final services = ref.read(appServicesProvider);
    try {
      await services.syncEngine.deleteLocalNote(noteId);
      _activeNoteId = null;
      _expectedHeadRevision = null;
    } catch (_) {
      // 退出清理失败不阻断返回流程。
    }
  }

  Future<bool> _onWillPop() async {
    await _flushAutosave();
    await _cleanupNewNoteOnExit();
    return true;
  }

  void _switchViewMode(_EditorViewMode mode) {
    if (_viewMode == mode) {
      return;
    }
    if (mode == _EditorViewMode.preview) {
      FocusScope.of(context).unfocus();
    }
    setState(() {
      _viewMode = mode;
    });

    if (mode == _EditorViewMode.preview && !_previewScrollInitialized) {
      _previewScrollInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncPreviewScrollFromEdit();
      });
    }
  }

  /// 首次进入预览时按滚动比例对齐，避免从顶部突变。
  void _syncPreviewScrollFromEdit() {
    if (!mounted) {
      return;
    }
    if (!_editScrollController.hasClients || !_previewScrollController.hasClients) {
      return;
    }
    final editMax = _editScrollController.position.maxScrollExtent;
    final ratio =
        editMax <= 0
            ? 0.0
            : (_editScrollController.offset / editMax).clamp(0.0, 1.0).toDouble();
    final previewMax = _previewScrollController.position.maxScrollExtent;
    final target = (previewMax * ratio).clamp(0.0, previewMax).toDouble();
    _previewScrollController.jumpTo(target);
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _savedHintTimer?.cancel();
    _titleController.removeListener(_onDraftChanged);
    _contentController.removeListener(_onDraftChanged);
    _titleController.dispose();
    _contentController.dispose();
    _editScrollController.dispose();
    _previewScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = _isNewNoteSession ? l10n.newNote : l10n.editNote;
    final colorScheme = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(
                width: 150,
                child: CupertinoSlidingSegmentedControl<_EditorViewMode>(
                  groupValue: _viewMode,
                  thumbColor: colorScheme.primary.withValues(alpha: 0.22),
                  backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.38,
                  ),
                  children: {
                    _EditorViewMode.edit: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(l10n.editorMode),
                    ),
                    _EditorViewMode.preview: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(l10n.previewMode),
                    ),
                  },
                  onValueChanged: (value) {
                    if (value != null) {
                      _switchViewMode(value);
                    }
                  },
                ),
              ),
            ),
            IconButton(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return colorScheme.onSurface.withValues(alpha: 0.38);
                  }
                  return colorScheme.primary.withValues(alpha: 0.78);
                }),
              ),
              onPressed: _isSaving ? null : _saveNow,
              icon: const Icon(Icons.save_outlined),
              tooltip: l10n.save,
            ),
            if (!_isNewNoteSession)
              IconButton(
                onPressed: _isSaving ? null : _confirmAndDeleteNote,
                icon: Icon(
                  CupertinoIcons.trash,
                  color: Theme.of(context).colorScheme.error,
                ),
                tooltip: l10n.delete,
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.pageBackground(Theme.of(context).brightness),
          ),
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SafeArea(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child:
                                _viewMode == _EditorViewMode.edit
                                    ? _buildEditBody()
                                    : _buildPreviewBody(),
                          ),
                        ),
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: IgnorePointer(
                            child: IosFrostedPanel(
                              radius: 14,
                              blur: 14,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder: (child, animation) {
                                        return SizeTransition(
                                          sizeFactor: animation,
                                          axis: Axis.horizontal,
                                          axisAlignment: 1,
                                          child: FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child:
                                          _showSavedHintInBadge
                                              ? Padding(
                                                key: const ValueKey<String>(
                                                  'saved',
                                                ),
                                                padding: const EdgeInsets.only(
                                                  right: 6,
                                                ),
                                                child: Text(
                                                  l10n.saved,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color:
                                                            AppColors.textPrimary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              )
                                              : const SizedBox.shrink(
                                                key: ValueKey<String>('empty'),
                                              ),
                                    ),
                                    Text(
                                      l10n.charCountLabel(_contentCharCount),
                                      style: Theme.of(context).textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }

  /// 编辑模式 UI：标题输入 + 正文输入。
  Widget _buildEditBody() {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        const titleAreaEstimate = 72.0;
        final contentMinHeight =
            (constraints.maxHeight - titleAreaEstimate)
                .clamp(140.0, double.infinity)
                .toDouble();

        return ListView(
          controller: _editScrollController,
          padding: const EdgeInsets.only(top: 6, bottom: 72),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          children: [
            TextField(
              controller: _titleController,
              maxLines: 1,
              textInputAction: TextInputAction.next,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 34,
                letterSpacing: -0.8,
              ),
              decoration: InputDecoration(
                hintText: l10n.titleHint,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            const Divider(height: 1, thickness: 1),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: contentMinHeight),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: l10n.markdownHint,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 预览模式 UI：标题文本 + Markdown 渲染内容。
  Widget _buildPreviewBody() {
    final l10n = context.l10n;
    final title = _titleController.text.trim();
    final content = _contentController.text;
    final showEmptyHint = content.trim().isEmpty;

    return ListView(
      controller: _previewScrollController,
      padding: const EdgeInsets.only(top: 6, bottom: 72),
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 34, letterSpacing: -0.8),
            ),
          ),
        const Divider(height: 1, thickness: 1),
        if (showEmptyHint)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              l10n.markdownHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: MarkdownBody(
              data: content,
              styleSheet: _buildMarkdownStyle(context),
              selectable: true,
            ),
          ),
      ],
    );
  }

  MarkdownStyleSheet _buildMarkdownStyle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyLarge?.copyWith(height: 1.62),
      h1: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      h2: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      h3: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      blockquote: theme.textTheme.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      blockquoteDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.45),
            width: 3,
          ),
        ),
      ),
      code: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.68,
        ),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
      ),
      listBullet: theme.textTheme.bodyLarge,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }

  Future<void> _saveNow() async {
    await _flushAutosave();
    if (!mounted) {
      return;
    }
    _savedHintTimer?.cancel();
    setState(() {
      _showSavedHintInBadge = true;
    });
    _savedHintTimer = Timer(_savedHintHold, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showSavedHintInBadge = false;
      });
    });
  }

  Future<void> _confirmAndDeleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.deleteNoteTitle),
          content: Text(l10n.deleteNoteConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }
    await _deleteNote();
  }

  /// 软删除当前笔记。
  Future<void> _deleteNote() async {
    final id = _activeNoteId;
    if (id == null) {
      return;
    }

    setState(() => _isSaving = true);
    final services = ref.read(appServicesProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final deletedMessage = l10n.selectedDeleted(1);
    final restoredMessage = l10n.selectedRestored(1);
    final undoLabel = l10n.undo;
    final undoColor = Theme.of(context).colorScheme.primary;
    try {
      await services.syncEngine.deleteLocalNote(id);
      _activeNoteId = null;
      _expectedHeadRevision = null;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          duration: _deleteUndoSnackDuration,
          content: Row(
            children: [
              Expanded(child: Text(deletedMessage)),
              TextButton(
                onPressed: () async {
                  messenger.hideCurrentSnackBar();
                  await services.syncEngine.restoreDeletedLocalNote(id);
                  messenger.showSnackBar(
                    SnackBar(
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
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          duration: _restoreHintDuration,
          content: Text(l10n.deleteFailedWithReason(e.toString())),
        ),
      );
      setState(() => _isSaving = false);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
