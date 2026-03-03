import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/note_doc_codec.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/models/app_services.dart';
import '../../../domain/services/sync_engine.dart';

/// 笔记编辑会话控制器。
///
/// 目标：
/// - 负责加载/保存/退出清理，避免页面文件承担过多业务逻辑；
/// - 为 UI 暴露轻量状态（loading/saving/markdown/charCount）；
/// - 用定时轮询实现自动保存，减少对编辑器内部事件的耦合。
class NoteEditorController {
  NoteEditorController({required this.services, required this.initialNoteId});

  final AppServices services;
  final String? initialNoteId;

  static const Duration _autoSaveInterval = Duration(milliseconds: 700);

  final ValueNotifier<bool> loadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> savingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> markdownNotifier = ValueNotifier<String>(
    NoteDocCodec.buildNewNoteMarkdown(),
  );
  final ValueNotifier<int> charCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);

  EditorState? _editorState;
  Timer? _autoSaveTimer;
  String? _currentNoteId;
  int? _expectedHeadRevision;
  bool _createdDuringSession = false;
  String? _initialDraftDocJson;
  String _lastSavedDocJson = '';
  bool _disposed = false;
  bool _savingInFlight = false;

  /// 当前编辑器状态（由页面用于渲染 AppFlowyEditor）。
  EditorState? get editorState => _editorState;

  /// 当前会话对应的笔记 ID。
  String? get currentNoteId => _currentNoteId;

  /// 初始化编辑会话。
  Future<void> initialize() async {
    loadingNotifier.value = true;
    errorNotifier.value = null;
    try {
      final existing =
          initialNoteId == null
              ? null
              : await services.noteRepository.getByNoteId(initialNoteId!);

      final document =
          existing == null
              ? NoteDocCodec.buildInitialDocument()
              : NoteDocCodec.decodeDocument(
                contentDocJson: existing.contentDocJson,
                fallbackMarkdown: NoteDocCodec.buildMarkdownFromLegacy(
                  title: existing.title,
                  contentMd: existing.contentMd,
                ),
                fallbackTitle: existing.title,
              );
      _editorState = EditorState(document: document);
      _currentNoteId = existing?.noteId;
      _expectedHeadRevision = existing?.headRevision;

      final snapshot = NoteDocCodec.fromDocument(_editorState!.document);
      if (existing == null) {
        _initialDraftDocJson = snapshot.contentDocJson;
      }
      markdownNotifier.value = snapshot.contentMd;
      charCountNotifier.value = _countCharacters(snapshot.contentMd);
      _lastSavedDocJson = existing == null ? '' : snapshot.contentDocJson;

      _autoSaveTimer = Timer.periodic(_autoSaveInterval, (_) {
        unawaited(saveIfNeeded());
      });
    } catch (e) {
      errorNotifier.value = e.toString();
      AppLog.e('note-editor', 'initialize failed: $e');
    } finally {
      loadingNotifier.value = false;
    }
  }

  /// 手动保存（点击保存按钮触发）。
  Future<bool> saveNow() async {
    return _flush(force: true);
  }

  /// 自动保存入口（仅在内容变化时入库）。
  Future<bool> saveIfNeeded() async {
    return _flush(force: false);
  }

  Future<bool> _flush({required bool force}) async {
    if (_disposed || _savingInFlight) {
      return false;
    }
    final state = _editorState;
    if (state == null) {
      return false;
    }

    final snapshot = NoteDocCodec.fromDocument(state.document);
    markdownNotifier.value = snapshot.contentMd;
    charCountNotifier.value = _countCharacters(snapshot.contentMd);

    final changed = snapshot.contentDocJson != _lastSavedDocJson;
    if (!changed && !force) {
      return false;
    }

    // 新建草稿仅包含默认标题时不立即落库，避免产生空笔记。
    if (_currentNoteId == null && _isInitialDraft(snapshot.contentDocJson)) {
      return false;
    }

    _savingInFlight = true;
    savingNotifier.value = true;
    errorNotifier.value = null;
    try {
      final outcome = await services.syncEngine.saveLocalNote(
        noteId: _currentNoteId,
        contentDocJson: snapshot.contentDocJson,
        expectedHeadRevision: _expectedHeadRevision,
        source: SaveTriggerSource.localUser,
      );
      _currentNoteId = outcome.note.noteId;
      _expectedHeadRevision = outcome.note.headRevision;
      _createdDuringSession = _createdDuringSession || outcome.isNew;
      _lastSavedDocJson = snapshot.contentDocJson;
      return true;
    } catch (e) {
      errorNotifier.value = e.toString();
      AppLog.e('note-editor', 'save failed: $e');
      return false;
    } finally {
      _savingInFlight = false;
      savingNotifier.value = false;
    }
  }

  /// 页面退出前调用：
  /// 1) 尝试保存最后一次修改；
  /// 2) 若为本次新建且最终为空，则自动删除该笔记。
  Future<void> onLeavingEditor() async {
    await saveIfNeeded();
    final noteId = _currentNoteId;
    if (!_createdDuringSession || noteId == null) {
      return;
    }

    final state = _editorState;
    if (state == null) {
      return;
    }
    final currentSnapshot = NoteDocCodec.fromDocument(state.document);
    if (!_isInitialDraft(currentSnapshot.contentDocJson)) {
      return;
    }
    await services.syncEngine.deleteLocalNote(noteId);
  }

  /// 删除当前笔记。
  Future<void> deleteCurrentNote() async {
    final noteId = _currentNoteId;
    if (noteId == null) {
      return;
    }
    await services.syncEngine.deleteLocalNote(noteId);
  }

  /// 恢复最近删除的当前笔记。
  Future<void> restoreDeletedCurrentNote() async {
    final noteId = _currentNoteId;
    if (noteId == null) {
      return;
    }
    await services.syncEngine.restoreDeletedLocalNote(noteId);
  }

  /// 新建草稿是否仍处于初始模板状态（用于保存/退出删除判定）。
  bool _isInitialDraft(String docJson) {
    final initial = _initialDraftDocJson;
    if (initial == null) {
      return false;
    }
    return docJson == initial;
  }

  int _countCharacters(String markdown) {
    return markdown.replaceAll(RegExp(r'\s+'), '').runes.length;
  }

  /// 释放资源。
  void dispose() {
    _disposed = true;
    _autoSaveTimer?.cancel();
    _editorState?.dispose();
    loadingNotifier.dispose();
    savingNotifier.dispose();
    markdownNotifier.dispose();
    charCountNotifier.dispose();
    errorNotifier.dispose();
  }
}
