import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/note_doc_codec.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/models/app_services.dart';
import '../../../data/isar/collections/note_entity.dart';
import '../../../domain/services/sync_engine.dart';

/// 笔记编辑会话控制器。
///
/// 目标：
/// - 负责加载/保存/退出清理，避免页面文件承担过多业务逻辑；
/// - 为 UI 暴露轻量状态（loading/saving/markdown/charCount）；
/// - 使用“文档变更事件 + 防抖”自动保存，避免轮询写库。
class NoteEditorController {
  NoteEditorController({required this.services, required this.initialNoteId});

  /// 应用级服务集合（仓库、同步引擎等）。
  final AppServices services;

  /// 进入编辑页时传入的目标笔记 ID；`null` 表示新建。
  final String? initialNoteId;

  /// 自动保存防抖窗口。
  static const Duration _saveDebounceWindow = Duration(milliseconds: 800);

  /// 页面初始化/加载状态。
  final ValueNotifier<bool> loadingNotifier = ValueNotifier<bool>(true);

  /// 当前是否正在执行保存请求。
  final ValueNotifier<bool> savingNotifier = ValueNotifier<bool>(false);

  /// 自动保存是否正在执行（用于右上角状态提示）。
  final ValueNotifier<bool> autoSavingNotifier = ValueNotifier<bool>(false);

  /// 当前文档对应的 markdown 快照（用于预览、字数统计等 UI）。
  final ValueNotifier<String> markdownNotifier = ValueNotifier<String>(
    NoteDocCodec.buildNewNoteMarkdown(),
  );

  /// 当前字符数（去除空白字符后统计）。
  final ValueNotifier<int> charCountNotifier = ValueNotifier<int>(0);

  /// 最近一次错误信息（供页面按需展示或调试）。
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);

  /// 编辑器状态对象（由页面拿去渲染 AppFlowyEditor）。
  EditorState? _editorState;

  /// 自动保存防抖计时器。
  Timer? _saveDebounceTimer;

  /// 当前会话绑定的笔记 ID（新建后会在首次保存后写入）。
  String? _currentNoteId;
  StreamSubscription<EditorTransactionValue>? _editorTransactionSub;
  StreamSubscription<NoteEntity?>? _currentNoteSub;
  String? _watchingNoteId;
  bool _applyingRemoteOverride = false;

  /// 标记本次会话是否创建了新笔记（用于离页空草稿清理）。
  bool _createdDuringSession = false;
  bool _openedWithExistingNote = false;

  /// 最近一次成功保存的文档 JSON 快照。
  ///
  /// 用于判断“是否发生变化”，避免无意义重复写库。
  String _lastSavedDocJson = '';
  String _lastObservedDocJson = '';

  /// 本次编辑会话是否发生过用户文本改动。
  ///
  /// 注意：即使用户后续改回原文，该标记仍保持 true。
  bool _hasUserEditedInSession = false;

  /// 控制器是否已释放。
  bool _disposed = false;

  /// 防止保存重入的互斥标记。
  bool _savingInFlight = false;

  /// 当前键盘可见状态（由页面侧持续同步）。
  ///
  /// 远端覆盖文档后，只有键盘可见且存在选区时才恢复光标；
  /// 键盘不可见时仅恢复滚动位置，避免阅读场景被强制激活光标。
  bool _keyboardVisible = false;

  /// 当前编辑器状态（由页面用于渲染 AppFlowyEditor）。
  EditorState? get editorState => _editorState;

  /// 当前会话对应的笔记 ID。
  String? get currentNoteId => _currentNoteId;
  bool get isEditingExistingNote => _openedWithExistingNote;
  bool get hasUserEditedInSession => _hasUserEditedInSession;

  /// 同步键盘可见状态。
  void setKeyboardVisible(bool visible) {
    _keyboardVisible = visible;
  }

  /// 初始化编辑会话。
  Future<void> initialize() async {
    loadingNotifier.value = true;
    errorNotifier.value = null;
    try {
      // 1) 读取已有笔记（编辑）或走新建流程。
      final existing =
          initialNoteId == null
              ? null
              : await services.noteRepository.getByNoteId(initialNoteId!);

      // 2) 构建编辑器文档：
      //    - 优先使用结构化 contentDocJson；
      //    - 若缺失/异常则回退 legacy markdown 兼容路径。
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
      _openedWithExistingNote = existing != null;
      _ensureCurrentNoteSubscription();

      // 3) 初始化预览与统计状态。
      final snapshot = NoteDocCodec.fromDocument(_editorState!.document);
      markdownNotifier.value = snapshot.contentMd;
      charCountNotifier.value = _countCharacters(snapshot.contentMd);
      _lastSavedDocJson = existing == null ? '' : snapshot.contentDocJson;
      _lastObservedDocJson = snapshot.contentDocJson;
      _attachEditorChangeListener();
    } catch (e) {
      errorNotifier.value = e.toString();
      AppLog.e('note-editor', 'initialize failed: $e');
    } finally {
      loadingNotifier.value = false;
    }
  }

  /// 立即保存（离页/生命周期场景）。
  Future<bool> saveNow() async {
    return _flush(allowWriteWhenSessionEdited: true, showForceSaving: true);
  }

  /// 应用切后台/退出前触发的保存入口。
  ///
  /// 仅当本次会话确实发生过用户改动时才会写库。
  Future<bool> saveOnAppLifecycleExit() async {
    if (!_hasUserEditedInSession) {
      return false;
    }
    _saveDebounceTimer?.cancel();
    return _flush(allowWriteWhenSessionEdited: true, showForceSaving: false);
  }

  Future<bool> _flush({
    required bool allowWriteWhenSessionEdited,
    required bool showForceSaving,
  }) async {
    // 基础保护：已释放 / 正在保存 / 无可用编辑器状态时直接返回。
    if (_disposed || _savingInFlight || _applyingRemoteOverride) {
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
    final shouldWrite =
        changed || (allowWriteWhenSessionEdited && _hasUserEditedInSession);
    if (!shouldWrite) {
      return false;
    }

    // 新建笔记若被完全清空，则不落库。
    if (_currentNoteId == null && _isDocumentEffectivelyEmpty(state.document)) {
      return false;
    }

    _savingInFlight = true;
    if (showForceSaving) {
      savingNotifier.value = true;
    }
    autoSavingNotifier.value = true;
    errorNotifier.value = null;
    try {
      // 统一通过 syncEngine 落库，确保本地保存与同步日志路径一致。
      final outcome = await services.syncEngine.saveLocalNote(
        noteId: _currentNoteId,
        contentDocJson: snapshot.contentDocJson,
        source: SaveTriggerSource.localUser,
      );
      final previousNoteId = _currentNoteId;
      _currentNoteId = outcome.note.noteId;
      _createdDuringSession = _createdDuringSession || outcome.isNew;
      _lastSavedDocJson = snapshot.contentDocJson;
      _lastObservedDocJson = snapshot.contentDocJson;
      if (previousNoteId != _currentNoteId) {
        _ensureCurrentNoteSubscription();
      }
      return true;
    } catch (e) {
      errorNotifier.value = e.toString();
      AppLog.e('note-editor', 'save failed: $e');
      return false;
    } finally {
      _savingInFlight = false;
      if (showForceSaving) {
        savingNotifier.value = false;
      }
      autoSavingNotifier.value = false;
    }
  }

  /// 页面退出前调用：
  /// 1) 尝试保存最后一次修改；
  /// 2) 若为本次新建且最终为空，则自动删除该笔记（若已落库）。
  Future<void> onLeavingEditor() async {
    final state = _editorState;
    if (state == null) {
      return;
    }
    _saveDebounceTimer?.cancel();

    if (_isDocumentEffectivelyEmpty(state.document)) {
      final noteId = _currentNoteId;
      if (_createdDuringSession && noteId != null) {
        await services.syncEngine.deleteLocalNote(noteId);
      }
      return;
    }

    // 本次会话无任何改动，则离页不触发保存。
    if (!_hasUserEditedInSession) {
      return;
    }

    // 离页前做一次即时保存，确保最后输入不会被防抖窗口吞掉。
    await saveNow();
  }

  void _attachEditorChangeListener() {
    final state = _editorState;
    if (state == null) {
      return;
    }
    final previousSub = _editorTransactionSub;
    if (previousSub != null) {
      unawaited(previousSub.cancel());
    }
    _editorTransactionSub = state.transactionStream.listen((_) {
      _onEditorDocumentMaybeChanged();
    });
  }

  void _detachEditorChangeListener() {
    final transactionSub = _editorTransactionSub;
    if (transactionSub != null) {
      unawaited(transactionSub.cancel());
    }
    _editorTransactionSub = null;
  }

  void _onEditorDocumentMaybeChanged() {
    if (_disposed || _applyingRemoteOverride) {
      return;
    }
    final state = _editorState;
    if (state == null) {
      return;
    }

    final snapshot = NoteDocCodec.fromDocument(state.document);
    markdownNotifier.value = snapshot.contentMd;
    charCountNotifier.value = _countCharacters(snapshot.contentMd);

    // 光标移动/选区变化不应触发保存。
    if (snapshot.contentDocJson == _lastObservedDocJson) {
      return;
    }

    _lastObservedDocJson = snapshot.contentDocJson;
    _hasUserEditedInSession = true;
    _scheduleDebouncedSave();
  }

  void _scheduleDebouncedSave() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(_saveDebounceWindow, () {
      unawaited(
        _flush(allowWriteWhenSessionEdited: false, showForceSaving: false),
      );
    });
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

  /// 当前文档是否已被用户清空（所有块文本均为空白）。
  bool isCurrentDocumentEmpty() {
    final state = _editorState;
    if (state == null) {
      return true;
    }
    return _isDocumentEffectivelyEmpty(state.document);
  }

  bool _isDocumentEffectivelyEmpty(Document document) {
    for (final block in document.root.children) {
      final text =
          _extractBlockText(block).replaceAll(RegExp(r'\s+'), '').trim();
      if (text.isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  String _extractBlockText(Node node) {
    // 递归提取节点及子节点纯文本，供草稿识别与兜底判断使用。
    final pieces = <String>[];
    final delta = node.delta;
    if (delta != null) {
      final text = delta.toPlainText().replaceAll('\n', ' ').trim();
      if (text.isNotEmpty) {
        pieces.add(text);
      }
    }
    for (final child in node.children) {
      final text = _extractBlockText(child);
      if (text.isNotEmpty) {
        pieces.add(text);
      }
    }
    return pieces.join(' ').trim();
  }

  int _countCharacters(String markdown) {
    // 按“非空白字符”统计，中文/emoji 等通过 runes 计数更稳妥。
    return markdown.replaceAll(RegExp(r'\s+'), '').runes.length;
  }

  void _ensureCurrentNoteSubscription() {
    final noteId = _currentNoteId;
    if (noteId == null) {
      final previousSub = _currentNoteSub;
      if (previousSub != null) {
        unawaited(previousSub.cancel());
      }
      _currentNoteSub = null;
      _watchingNoteId = null;
      return;
    }
    if (_watchingNoteId == noteId && _currentNoteSub != null) {
      return;
    }

    final previousSub = _currentNoteSub;
    if (previousSub != null) {
      unawaited(previousSub.cancel());
    }
    _watchingNoteId = noteId;
    _currentNoteSub = services.noteRepository.watchNoteById(noteId).listen((
      note,
    ) {
      unawaited(_handleRemoteNoteUpdate(note));
    });
  }

  Future<void> _handleRemoteNoteUpdate(NoteEntity? note) async {
    if (_disposed || note == null) {
      return;
    }
    if (note.noteId != _currentNoteId) {
      return;
    }
    if (note.lastEditorDeviceId ==
        services.localDeviceService.profile.deviceId) {
      return;
    }
    if (_savingInFlight || _applyingRemoteOverride) {
      return;
    }

    final nextDocument = NoteDocCodec.decodeDocument(
      contentDocJson: note.contentDocJson,
      fallbackMarkdown: NoteDocCodec.buildMarkdownFromLegacy(
        title: note.title,
        contentMd: note.contentMd,
      ),
      fallbackTitle: note.title,
    );
    final nextSnapshot = NoteDocCodec.fromDocument(nextDocument);
    if (nextSnapshot.contentDocJson == _lastSavedDocJson) {
      return;
    }

    _applyingRemoteOverride = true;
    try {
      await _replaceEditorDocument(nextDocument);
      final appliedSnapshot = NoteDocCodec.fromDocument(_editorState!.document);
      markdownNotifier.value = appliedSnapshot.contentMd;
      charCountNotifier.value = _countCharacters(appliedSnapshot.contentMd);
      _lastSavedDocJson = appliedSnapshot.contentDocJson;
      _lastObservedDocJson = appliedSnapshot.contentDocJson;
      AppLog.i('note-editor', 'applied remote update to current editing note');
    } catch (e) {
      AppLog.e('note-editor', 'apply remote update failed: $e');
    } finally {
      _applyingRemoteOverride = false;
    }
  }

  Future<void> _replaceEditorDocument(Document nextDocument) async {
    final state = _editorState;
    if (state == null) {
      return;
    }

    // 记录远端覆盖前的视图状态，用于应用后恢复，避免“跳到顶部”。
    final previousSelection = state.selection;
    final previousScrollOffset = state.scrollService?.dy;
    final shouldRestoreSelection =
        _keyboardVisible && previousSelection != null;

    final oldNodesCount = state.document.root.children.length;
    final newNodes = nextDocument.root.children
        .map((node) => node.copyWith())
        .toList(growable: true);
    if (newNodes.isEmpty) {
      newNodes.add(paragraphNode());
    }

    final transaction = state.transaction;
    if (oldNodesCount > 0) {
      // 一次性从根路径删除连续节点，避免逐个删除引发 path 漂移导致顺序错乱。
      transaction.deleteNodesAtPath([0], oldNodesCount);
    }
    // 使用“超大索引”强制走 Document.insert 的 parent/index 分支，
    // 避免命中 target 节点触发 insertBefore 导致整体倒序。
    transaction.insertNodes([1 << 20], newNodes);
    await state.apply(transaction);

    // 键盘弹起且之前存在选区时恢复光标（含路径/偏移裁剪，防止越界）。
    if (shouldRestoreSelection && previousSelection != null) {
      final clampedSelection = _clampSelectionToDocument(
        previousSelection,
        state.document,
      );
      state.selection = clampedSelection;
    }

    // 始终恢复滚动位置：即使无键盘/无光标，也维持用户阅读位置稳定。
    await _restoreScrollOffset(state, previousScrollOffset);
  }

  Future<void> _restoreScrollOffset(
    EditorState state,
    double? rawOffset,
  ) async {
    final scrollService = state.scrollService;
    if (scrollService == null || rawOffset == null) {
      return;
    }
    // 等待本帧布局完成后再恢复滚动，避免在旧约束上写入失效。
    await Future<void>.delayed(Duration.zero);
    if (_disposed) {
      return;
    }
    final min = scrollService.minScrollExtent;
    final max = scrollService.maxScrollExtent;
    final target = rawOffset.clamp(min, max).toDouble();
    scrollService.scrollTo(target);
  }

  Selection? _clampSelectionToDocument(Selection selection, Document document) {
    if (document.root.children.isEmpty) {
      return null;
    }
    final start = _clampPositionToDocument(selection.start, document);
    final end = _clampPositionToDocument(selection.end, document);
    if (start == null || end == null) {
      return null;
    }
    if (listEquals(start.path, end.path) && start.offset == end.offset) {
      return Selection.single(path: start.path, startOffset: start.offset);
    }
    return Selection(start: start, end: end);
  }

  Position? _clampPositionToDocument(Position position, Document document) {
    final clampedPath = _clampPathToDocument(position.path, document);
    if (clampedPath.isEmpty) {
      return null;
    }
    final targetNode = _nodeAtPath(document, clampedPath);
    final maxOffset = (targetNode.delta?.toPlainText().length ?? 0);
    final clampedOffset = position.offset.clamp(0, maxOffset).toInt();
    return Position(path: clampedPath, offset: clampedOffset);
  }

  List<int> _clampPathToDocument(List<int> path, Document document) {
    if (document.root.children.isEmpty) {
      return const <int>[];
    }
    // 空路径回退到首个根块，避免后续节点解析失败。
    if (path.isEmpty) {
      return <int>[0];
    }

    final result = <int>[];
    Node current = document.root;
    for (final rawIndex in path) {
      final children = current.children;
      if (children.isEmpty) {
        break;
      }
      final maxIndex = children.length - 1;
      final index = rawIndex.clamp(0, maxIndex).toInt();
      result.add(index);
      current = children[index];
    }
    if (result.isEmpty) {
      return <int>[0];
    }
    return result;
  }

  Node _nodeAtPath(Document document, List<int> path) {
    Node current = document.root;
    for (final index in path) {
      current = current.children[index];
    }
    return current;
  }

  /// 释放资源。
  void dispose() {
    _disposed = true;
    _saveDebounceTimer?.cancel();
    final noteSub = _currentNoteSub;
    if (noteSub != null) {
      unawaited(noteSub.cancel());
    }
    _detachEditorChangeListener();
    _editorState?.dispose();
    loadingNotifier.dispose();
    savingNotifier.dispose();
    autoSavingNotifier.dispose();
    markdownNotifier.dispose();
    charCountNotifier.dispose();
    errorNotifier.dispose();
  }
}
