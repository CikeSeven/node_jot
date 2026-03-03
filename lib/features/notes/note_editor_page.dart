import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/app_services.dart';
import '../../core/utils/note_doc_codec.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/ios_frosted_panel.dart';

/// 笔记编辑页。
///
/// 使用 AppFlowyEditor 编辑文档，首行 `# 标题` 作为标题来源。
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, this.noteId});

  final String? noteId;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  static const _autosaveDelay = Duration(milliseconds: 320);
  static const _docPollInterval = Duration(milliseconds: 420);
  static const _savedHintHold = Duration(seconds: 3);
  static const _deleteUndoSnackDuration = Duration(seconds: 4);
  static const _restoreHintDuration = Duration(seconds: 2);

  Timer? _autosaveTimer;
  Timer? _savedHintTimer;
  Timer? _docPollTimer;

  EditorState? _editorState;
  bool _loading = true;
  bool _isSaving = false;
  bool _hasPendingSave = false;
  bool _isBootstrapping = true;
  bool _showSavedHintInBadge = false;
  int? _expectedHeadRevision;
  String? _activeNoteId;
  String _lastSavedDocJson = '';
  String _observedDocJson = '';

  bool get _isNewNoteSession => widget.noteId == null;

  int get _contentCharCount => _currentMarkdown.characters.length;

  String get _currentMarkdown {
    final state = _editorState;
    if (state == null) {
      return '';
    }
    final snapshot = NoteDocCodec.fromDocument(state.document);
    return snapshot.contentMd;
  }

  @override
  void initState() {
    super.initState();
    _activeNoteId = widget.noteId;
    _load();
  }

  Future<void> _load() async {
    final services = ref.read(appServicesProvider);

    if (_activeNoteId == null) {
      final markdown = NoteDocCodec.buildNewNoteMarkdown();
      final document = NoteDocCodec.decodeDocument(fallbackMarkdown: markdown);
      _editorState = EditorState(document: document);
      final snapshot = NoteDocCodec.fromDocument(document);
      _lastSavedDocJson = snapshot.contentDocJson;
      _observedDocJson = snapshot.contentDocJson;
      _isBootstrapping = false;
      _startDocPolling();
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    final note = await services.noteRepository.getByNoteId(_activeNoteId!);
    if (note != null) {
      final document = NoteDocCodec.decodeDocument(
        contentDocJson: note.contentDocJson,
        fallbackMarkdown: note.contentMd,
        fallbackTitle: note.title,
      );
      _editorState = EditorState(document: document);
      _expectedHeadRevision = note.headRevision;
      final snapshot = NoteDocCodec.fromDocument(document);
      _lastSavedDocJson = snapshot.contentDocJson;
      _observedDocJson = snapshot.contentDocJson;
    } else {
      final markdown = NoteDocCodec.buildNewNoteMarkdown();
      final document = NoteDocCodec.decodeDocument(fallbackMarkdown: markdown);
      _editorState = EditorState(document: document);
      final snapshot = NoteDocCodec.fromDocument(document);
      _lastSavedDocJson = snapshot.contentDocJson;
      _observedDocJson = snapshot.contentDocJson;
    }

    _isBootstrapping = false;
    _startDocPolling();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _startDocPolling() {
    _docPollTimer?.cancel();
    _docPollTimer = Timer.periodic(_docPollInterval, (_) {
      _checkDocChanged();
    });
  }

  void _checkDocChanged() {
    if (_loading || _isBootstrapping || _editorState == null) {
      return;
    }
    final snapshot = NoteDocCodec.fromDocument(_editorState!.document);
    if (snapshot.contentDocJson == _observedDocJson) {
      return;
    }
    _observedDocJson = snapshot.contentDocJson;
    if (mounted) {
      setState(() {});
    }
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, () {
      unawaited(_saveDraft());
    });
  }

  bool _hasUnsavedChanges() {
    final state = _editorState;
    if (state == null) {
      return false;
    }
    final snapshot = NoteDocCodec.fromDocument(state.document);
    return snapshot.contentDocJson != _lastSavedDocJson;
  }

  Future<void> _saveDraft() async {
    final state = _editorState;
    if (_loading || _isBootstrapping || state == null || !_hasUnsavedChanges()) {
      return;
    }
    if (_isSaving) {
      _hasPendingSave = true;
      return;
    }

    _isSaving = true;
    final services = ref.read(appServicesProvider);
    final outgoing = NoteDocCodec.fromDocument(state.document);
    try {
      final result = await services.syncEngine.saveLocalNote(
        noteId: _activeNoteId,
        contentDocJson: outgoing.contentDocJson,
        expectedHeadRevision: _expectedHeadRevision,
      );
      _activeNoteId = result.note.noteId;
      _expectedHeadRevision = result.note.headRevision;
      _lastSavedDocJson = result.note.contentDocJson ?? outgoing.contentDocJson;
      _observedDocJson = _lastSavedDocJson;

      if (result.createdConflictCopy && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.conflictCopyCreated)));
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

    final content = _currentMarkdown.trim();
    final normalized = content
        .replaceFirst(RegExp(r'^#\s*标题\s*\n*'), '')
        .trim();
    if (normalized.isNotEmpty) {
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

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _savedHintTimer?.cancel();
    _docPollTimer?.cancel();
    _editorState?.dispose();
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
              _loading || _editorState == null
                  ? const Center(child: CircularProgressIndicator())
                  : SafeArea(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildEditor(),
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

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 72),
      child: AppFlowyEditor(
        editorState: _editorState!,
        shrinkWrap: false,
        autoFocus: false,
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
