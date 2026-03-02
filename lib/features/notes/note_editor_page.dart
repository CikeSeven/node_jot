import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/models/app_services.dart';
import '../../l10n/app_localizations.dart';

/// 笔记编辑页。
///
/// 支持创建、编辑、保存与软删除。
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, this.noteId});

  final String? noteId;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  static const _autosaveDelay = Duration(milliseconds: 300);

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  Timer? _autosaveTimer;

  bool _loading = true;
  bool _isSaving = false;
  bool _hasPendingSave = false;
  bool _isBootstrapping = true;
  bool _muteDraftListener = false;
  int? _expectedHeadRevision;
  String? _activeNoteId;
  String _lastSavedNormalizedTitle = '';
  String _lastSavedContent = '';

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

  void _onDraftChanged() {
    if (_loading || _isBootstrapping || _muteDraftListener) {
      return;
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

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _titleController.removeListener(_onDraftChanged);
    _contentController.removeListener(_onDraftChanged);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 顶部标题根据是否已有 noteId 区分“新建/编辑”。
    final title = _isNewNoteSession ? l10n.newNote : l10n.editNote;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            // 仅编辑已有笔记时展示手动删除入口。
            if (!_isNewNoteSession)
              IconButton(
                onPressed: _isSaving ? null : _deleteNote,
                icon: const Icon(CupertinoIcons.trash),
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: Container(
          // 编辑页背景渐变。
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
            ),
          ),
          child:
              _loading
                  // 首次载入旧笔记时的加载态。
                  ? const Center(child: CircularProgressIndicator())
                  : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Column(
                        children: [
                          // 标题输入区（位于应用栏下方）。
                          TextField(
                            controller: _titleController,
                            maxLines: 1,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: l10n.titleHint,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                          ),
                          // 标题与正文间的分割线。
                          const Divider(height: 1, thickness: 1),
                          // 正文输入区，填满剩余可用空间。
                          Expanded(
                            child: TextField(
                              controller: _contentController,
                              maxLines: null,
                              expands: true,
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
                      ),
                    ),
                  ),
        ),
      ),
    );
  }

  /// 软删除当前笔记。
  Future<void> _deleteNote() async {
    final id = _activeNoteId;
    if (id == null) {
      return;
    }

    setState(() => _isSaving = true);
    final services = ref.read(appServicesProvider);
    try {
      await services.syncEngine.deleteLocalNote(id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.deleteFailedWithReason(e.toString())),
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
