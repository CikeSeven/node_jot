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

  /// 应用级服务集合（仓库、同步引擎等）。
  final AppServices services;

  /// 进入编辑页时传入的目标笔记 ID；`null` 表示新建。
  final String? initialNoteId;

  /// 自动保存轮询间隔。
  ///
  /// 当前采用低耦合策略：定时检查文档快照变化，而不是强依赖编辑器事件流。
  static const Duration _autoSaveInterval = Duration(milliseconds: 700);

  /// 页面初始化/加载状态。
  final ValueNotifier<bool> loadingNotifier = ValueNotifier<bool>(true);

  /// 当前是否正在执行保存请求。
  final ValueNotifier<bool> savingNotifier = ValueNotifier<bool>(false);

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

  /// 自动保存轮询定时器。
  Timer? _autoSaveTimer;

  /// 当前会话绑定的笔记 ID（新建后会在首次保存后写入）。
  String? _currentNoteId;

  /// 乐观并发保存所需的预期头版本号。
  int? _expectedHeadRevision;

  /// 标记本次会话是否创建了新笔记（用于离页空草稿清理）。
  bool _createdDuringSession = false;

  /// 最近一次成功保存的文档 JSON 快照。
  ///
  /// 用于判断“是否发生变化”，避免无意义重复写库。
  String _lastSavedDocJson = '';

  /// 控制器是否已释放。
  bool _disposed = false;

  /// 防止保存重入的互斥标记。
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
      _expectedHeadRevision = existing?.headRevision;

      // 3) 初始化预览与统计状态。
      final snapshot = NoteDocCodec.fromDocument(_editorState!.document);
      markdownNotifier.value = snapshot.contentMd;
      charCountNotifier.value = _countCharacters(snapshot.contentMd);
      _lastSavedDocJson = existing == null ? '' : snapshot.contentDocJson;

      // 4) 启动自动保存轮询。
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
    // 基础保护：已释放 / 正在保存 / 无可用编辑器状态时直接返回。
    if (_disposed || _savingInFlight) {
      return false;
    }
    final state = _editorState;
    if (state == null) {
      return false;
    }

    try {
      // 对“被当纯文本的 markdown”进行一次轻量规范化，避免展示为原始文本。
      await _normalizeMarkdownLikeContentIfNeeded(state);
    } catch (e) {
      errorNotifier.value = e.toString();
      AppLog.e('note-editor', 'normalize markdown failed: $e');
      return false;
    }
    final snapshot = NoteDocCodec.fromDocument(state.document);
    markdownNotifier.value = snapshot.contentMd;
    charCountNotifier.value = _countCharacters(snapshot.contentMd);

    final changed = snapshot.contentDocJson != _lastSavedDocJson;
    if (!changed && !force) {
      // 自动保存且无变化时跳过写库。
      return false;
    }

    // 新建草稿仅包含默认标题时不立即落库，避免产生空笔记。
    if (_currentNoteId == null && _isInitialDraftDocument(state.document)) {
      return false;
    }

    _savingInFlight = true;
    savingNotifier.value = true;
    errorNotifier.value = null;
    try {
      // 统一通过 syncEngine 落库，确保本地保存与同步日志路径一致。
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
    // 离页前先做一次兜底保存，降低“最后一次输入丢失”的概率。
    await saveIfNeeded();
    final noteId = _currentNoteId;
    if (!_createdDuringSession || noteId == null) {
      return;
    }

    final state = _editorState;
    if (state == null) {
      return;
    }
    if (!_isInitialDraftDocument(state.document)) {
      return;
    }

    // 仅对“本次新建且仍是空草稿”的笔记执行自动删除。
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

  /// 新建草稿是否仍处于初始模板状态（仅含默认 H1 标题且无正文）。
  bool _isInitialDraftDocument(Document document) {
    final blocks = document.root.children;
    if (blocks.isEmpty) {
      return true;
    }

    var hasDefaultH1 = false;
    for (final block in blocks) {
      // 统一压缩空白后比较，避免换行/多空格影响判断。
      final text =
          _extractBlockText(block).replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isEmpty) {
        continue;
      }

      final level = (block.attributes['level'] as num?)?.toInt();
      final isDefaultHeading =
          block.type == 'heading' &&
          level == 1 &&
          (text == NoteDocCodec.defaultHeading || text.toLowerCase() == 'title');
      if (isDefaultHeading && !hasDefaultH1) {
        hasDefaultH1 = true;
        continue;
      }
      return false;
    }

    return hasDefaultH1;
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

  /// 自动识别“纯文本 markdown”并转换为结构化块文档。
  ///
  /// 主要覆盖两类场景：
  /// - 其他端同步来的 markdown 被当作普通段落；
  /// - 用户一次性粘贴大段 markdown 原文。
  Future<void> _normalizeMarkdownLikeContentIfNeeded(EditorState state) async {
    try {
      final normalized = NoteDocCodec.normalizeMarkdownLikePlainDocument(
        state.document,
        fallbackHeading: NoteDocCodec.defaultHeading,
      );
      if (normalized == null) {
        return;
      }

      final transaction = state.transaction;
      final existingNodes = state.document.root.children.toList(growable: false);
      if (existingNodes.isNotEmpty) {
        // 整体替换为解析后的结构化块，保证文档结构一致。
        transaction.deleteNodes(existingNodes);
      }
      final nextNodes = normalized.root.children.map((node) => node.copyWith());
      transaction.insertNodes(const [0], nextNodes);
      transaction.afterSelection = Selection.single(path: [0], startOffset: 0);
      await state.apply(
        transaction,
        // 这是系统级规范化，不应污染用户撤销栈。
        options: const ApplyOptions(recordUndo: false),
      );
    } catch (e) {
      AppLog.e('note-editor', 'normalize markdown exception: $e');
      rethrow;
    }
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
