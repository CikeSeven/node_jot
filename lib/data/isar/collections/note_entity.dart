import 'package:isar/isar.dart';

part 'note_entity.g.dart';

/// 笔记实体。
///
/// `baseRevision/headRevision` 用于同步快进与冲突检测。
@collection
class NoteEntity {
  /// Isar 内部主键。
  Id isarId = Isar.autoIncrement;

  /// 业务主键（UUID），跨设备同步时保持不变。
  @Index(unique: true, replace: true)
  late String noteId;

  /// 旧版独立标题字段（迁移兼容，后续不再作为主来源）。
  late String title;

  /// 结构化文档 JSON（当前为 quill delta，主存储）。
  String? contentDocJson;

  /// 文档结构版本号。
  int docVersion = 1;

  /// 列表展示标题缓存（由文档首个 `#` 标题提取）。
  String? displayTitleCache;

  /// 列表摘要缓存（由文档正文提取）。
  String? previewTextCache;

  /// 文档渲染模式标记（当前固定为 `quill_delta`）。
  String? contentFormat;

  /// 快照 schema 版本（用于同步协议版本控制）。
  int schemaVersion = 1;

  late String contentMd;
  late DateTime updatedAt;
  DateTime? deletedAt;
  DateTime? archivedAt;
  late String lastEditorDeviceId;
  late int baseRevision;
  late int headRevision;
  bool isConflictCopy = false;
  String? originNoteId;
}
