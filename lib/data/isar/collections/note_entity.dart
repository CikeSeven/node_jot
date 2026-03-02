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

  late String title;
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
