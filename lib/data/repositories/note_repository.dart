import 'dart:convert';

import 'package:isar/isar.dart';

import '../../core/utils/id.dart';
import '../isar/collections/note_entity.dart';

/// 本地保存笔记后的结果。
class SaveNoteOutcome {
  const SaveNoteOutcome({
    required this.note,
    required this.isNew,
    required this.createdConflictCopy,
  });

  final NoteEntity note;
  final bool isNew;
  final bool createdConflictCopy;
}

/// 应用远端快照后的结果。
class ApplyRemoteOutcome {
  const ApplyRemoteOutcome({
    required this.noteId,
    required this.createdConflictCopy,
  });

  final String noteId;
  final bool createdConflictCopy;
}

/// 笔记仓储。
///
/// 负责笔记 CRUD、远端快照落库与冲突副本策略。
class NoteRepository {
  NoteRepository(this._db);

  final Isar _db;

  /// 监听未删除笔记（按更新时间倒序）。
  Stream<List<NoteEntity>> watchActiveNotes() {
    return _db.noteEntitys
        .where()
        .filter()
        .deletedAtIsNull()
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: true);
  }

  /// 监听冲突副本笔记。
  Stream<List<NoteEntity>> watchConflictNotes() {
    return _db.noteEntitys
        .where()
        .filter()
        .isConflictCopyEqualTo(true)
        .deletedAtIsNull()
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: true);
  }

  /// 按业务 ID 查询笔记。
  Future<NoteEntity?> getByNoteId(String noteId) {
    return _db.noteEntitys.where().noteIdEqualTo(noteId).findFirst();
  }

  /// 保存本地编辑。
  ///
  /// - 新笔记：创建 `headRevision=1`；
  /// - 旧笔记：正常快进 revision；
  /// - revision 不匹配：创建冲突副本，避免覆盖现有内容。
  Future<SaveNoteOutcome> saveLocalNote({
    required String title,
    required String contentMd,
    required String editorDeviceId,
    String? noteId,
    int? expectedHeadRevision,
  }) async {
    final normalizedTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
    final now = DateTime.now().toUtc();
    final wantedNoteId = noteId ?? newUuid();

    late SaveNoteOutcome outcome;

    await _db.writeTxn(() async {
      final existing =
          await _db.noteEntitys.where().noteIdEqualTo(wantedNoteId).findFirst();

      if (existing == null) {
        final note =
            NoteEntity()
              ..noteId = wantedNoteId
              ..title = normalizedTitle
              ..contentMd = contentMd
              ..updatedAt = now
              ..deletedAt = null
              ..lastEditorDeviceId = editorDeviceId
              ..baseRevision = 0
              ..headRevision = 1
              ..isConflictCopy = false
              ..originNoteId = null;
        await _db.noteEntitys.put(note);
        outcome = SaveNoteOutcome(
          note: note,
          isNew: true,
          createdConflictCopy: false,
        );
        return;
      }

      if (expectedHeadRevision != null &&
          existing.headRevision != expectedHeadRevision) {
        final conflict =
            NoteEntity()
              ..noteId = newUuid()
              ..title = '$normalizedTitle (Conflict)'
              ..contentMd = contentMd
              ..updatedAt = now
              ..deletedAt = null
              ..lastEditorDeviceId = editorDeviceId
              ..baseRevision = existing.headRevision
              ..headRevision = existing.headRevision + 1
              ..isConflictCopy = true
              ..originNoteId = existing.noteId;
        await _db.noteEntitys.put(conflict);
        outcome = SaveNoteOutcome(
          note: conflict,
          isNew: true,
          createdConflictCopy: true,
        );
        return;
      }

      existing
        ..title = normalizedTitle
        ..contentMd = contentMd
        ..updatedAt = now
        ..deletedAt = null
        ..lastEditorDeviceId = editorDeviceId
        ..baseRevision = existing.headRevision
        ..headRevision = existing.headRevision + 1;

      await _db.noteEntitys.put(existing);
      outcome = SaveNoteOutcome(
        note: existing,
        isNew: false,
        createdConflictCopy: false,
      );
    });

    return outcome;
  }

  /// 本地软删除笔记。
  Future<void> softDeleteLocalNote({
    required String noteId,
    required String editorDeviceId,
  }) async {
    await _db.writeTxn(() async {
      final existing =
          await _db.noteEntitys.where().noteIdEqualTo(noteId).findFirst();
      if (existing == null) {
        return;
      }

      final now = DateTime.now().toUtc();
      existing
        ..deletedAt = now
        ..lastEditorDeviceId = editorDeviceId
        ..baseRevision = existing.headRevision
        ..headRevision = existing.headRevision + 1
        ..updatedAt = now;
      await _db.noteEntitys.put(existing);
    });
  }

  /// 应用远端笔记快照。
  ///
  /// 若无法基于 `baseRevision` 快进，则创建远端冲突副本。
  Future<ApplyRemoteOutcome> applyRemoteSnapshot(
    Map<String, dynamic> snapshot,
  ) async {
    final noteId = snapshot['noteId'] as String;
    final title = (snapshot['title'] as String?) ?? 'Untitled';
    final content = (snapshot['contentMd'] as String?) ?? '';
    final updatedAt = DateTime.parse(snapshot['updatedAt'] as String).toUtc();
    final deletedAtRaw = snapshot['deletedAt'] as String?;
    final deletedAt =
        deletedAtRaw == null ? null : DateTime.parse(deletedAtRaw).toUtc();
    final lastEditorDeviceId = snapshot['lastEditorDeviceId'] as String;
    final baseRevision = snapshot['baseRevision'] as int;
    final headRevision = snapshot['headRevision'] as int;
    final incomingConflict = (snapshot['isConflictCopy'] as bool?) ?? false;
    final originNoteId = snapshot['originNoteId'] as String?;

    late ApplyRemoteOutcome outcome;

    await _db.writeTxn(() async {
      final local =
          await _db.noteEntitys.where().noteIdEqualTo(noteId).findFirst();
      if (local == null) {
        final fresh =
            NoteEntity()
              ..noteId = noteId
              ..title = title
              ..contentMd = content
              ..updatedAt = updatedAt
              ..deletedAt = deletedAt
              ..lastEditorDeviceId = lastEditorDeviceId
              ..baseRevision = baseRevision
              ..headRevision = headRevision
              ..isConflictCopy = incomingConflict
              ..originNoteId = originNoteId;
        await _db.noteEntitys.put(fresh);
        outcome = ApplyRemoteOutcome(
          noteId: fresh.noteId,
          createdConflictCopy: false,
        );
        return;
      }

      final canFastForward =
          incomingConflict || local.headRevision == baseRevision;

      if (canFastForward) {
        local
          ..title = title
          ..contentMd = content
          ..updatedAt = updatedAt
          ..deletedAt = deletedAt
          ..lastEditorDeviceId = lastEditorDeviceId
          ..baseRevision = baseRevision
          ..headRevision = headRevision
          ..isConflictCopy = incomingConflict
          ..originNoteId = originNoteId;
        await _db.noteEntitys.put(local);
        outcome = ApplyRemoteOutcome(
          noteId: local.noteId,
          createdConflictCopy: false,
        );
        return;
      }

      final conflictCopy =
          NoteEntity()
            ..noteId = newUuid()
            ..title =
                '${title.trim().isEmpty ? 'Untitled' : title} (Remote Conflict)'
            ..contentMd = content
            ..updatedAt = updatedAt
            ..deletedAt = deletedAt
            ..lastEditorDeviceId = lastEditorDeviceId
            ..baseRevision = baseRevision
            ..headRevision = headRevision
            ..isConflictCopy = true
            ..originNoteId = noteId;

      await _db.noteEntitys.put(conflictCopy);
      outcome = ApplyRemoteOutcome(
        noteId: conflictCopy.noteId,
        createdConflictCopy: true,
      );
    });

    return outcome;
  }

  /// 应用远端删除快照。
  ///
  /// 如果本地不存在该笔记，会创建墓碑记录（ghost note），用于同步一致性。
  Future<void> softDeleteRemoteNote({
    required String noteId,
    required DateTime deletedAt,
    required String editorDeviceId,
    required int baseRevision,
    required int headRevision,
  }) async {
    await _db.writeTxn(() async {
      final local =
          await _db.noteEntitys.where().noteIdEqualTo(noteId).findFirst();
      if (local == null) {
        final ghost =
            NoteEntity()
              ..noteId = noteId
              ..title = 'Deleted Note'
              ..contentMd = ''
              ..updatedAt = deletedAt
              ..deletedAt = deletedAt
              ..lastEditorDeviceId = editorDeviceId
              ..baseRevision = baseRevision
              ..headRevision = headRevision
              ..isConflictCopy = false
              ..originNoteId = null;
        await _db.noteEntitys.put(ghost);
        return;
      }

      local
        ..deletedAt = deletedAt
        ..updatedAt = deletedAt
        ..lastEditorDeviceId = editorDeviceId
        ..baseRevision = baseRevision
        ..headRevision = headRevision;
      await _db.noteEntitys.put(local);
    });
  }

  /// 将实体转换为可同步快照。
  Map<String, dynamic> toSnapshot(NoteEntity note) {
    return {
      'noteId': note.noteId,
      'title': note.title,
      'contentMd': note.contentMd,
      'updatedAt': note.updatedAt.toUtc().toIso8601String(),
      'deletedAt': note.deletedAt?.toUtc().toIso8601String(),
      'lastEditorDeviceId': note.lastEditorDeviceId,
      'baseRevision': note.baseRevision,
      'headRevision': note.headRevision,
      'isConflictCopy': note.isConflictCopy,
      'originNoteId': note.originNoteId,
    };
  }

  /// 将笔记快照转为 JSON。
  String toSnapshotJson(NoteEntity note) {
    return jsonEncode(toSnapshot(note));
  }
}
