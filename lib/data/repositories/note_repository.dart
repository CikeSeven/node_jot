import 'dart:convert';

import 'package:isar/isar.dart';

import '../../core/utils/id.dart';
import '../../core/utils/note_doc_codec.dart';
import '../isar/collections/note_entity.dart';
import '../isar/collections/op_log_entity.dart';

/// 本地保存笔记后的结果。
class SaveNoteOutcome {
  const SaveNoteOutcome({
    required this.note,
    required this.isNew,
    required this.createdConflictCopy,
    required this.hasInlineConflict,
  });

  final NoteEntity note;
  final bool isNew;
  final bool createdConflictCopy;
  final bool hasInlineConflict;
}

/// 应用远端快照后的结果。
class ApplyRemoteOutcome {
  const ApplyRemoteOutcome({
    required this.noteId,
    required this.createdConflictCopy,
    required this.hasInlineConflict,
  });

  final String noteId;
  final bool createdConflictCopy;
  final bool hasInlineConflict;
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
        .archivedAtIsNull()
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: true);
  }

  /// 监听已归档且未删除的笔记（按更新时间倒序）。
  Stream<List<NoteEntity>> watchArchivedNotes() {
    return _db.noteEntitys
        .where()
        .filter()
        .deletedAtIsNull()
        .archivedAtIsNotNull()
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
        .archivedAtIsNull()
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: true);
  }

  /// 按业务 ID 查询笔记。
  Future<NoteEntity?> getByNoteId(String noteId) {
    return _db.noteEntitys.where().noteIdEqualTo(noteId).findFirst();
  }

  /// 迁移旧版 `title + contentMd` 到 `contentDocJson` 主存储。
  Future<void> migrateLegacyNotesToDocJson() async {
    final allNotes = await _db.noteEntitys.where().findAll();
    for (final note in allNotes) {
      final changed = await _migrateSingleNote(note);
      if (!changed) {
        continue;
      }
      await _db.writeTxn(() async {
        await _db.noteEntitys.put(note);
      });
    }
  }

  /// 保存本地编辑。
  ///
  /// - 新笔记：创建 `headRevision=1`；
  /// - 旧笔记：正常快进 revision；
  /// - revision 不匹配：保留当前笔记并创建冲突副本。
  Future<SaveNoteOutcome> saveLocalNote({
    required String contentDocJson,
    required String editorDeviceId,
    String? noteId,
    int? expectedHeadRevision,
  }) async {
    final now = DateTime.now().toUtc();
    final wantedNoteId = noteId ?? newUuid();
    final incomingDoc = NoteDocCodec.fromDocJson(docJson: contentDocJson);

    late SaveNoteOutcome outcome;

    await _db.writeTxn(() async {
      final existing =
          await _db.noteEntitys.where().noteIdEqualTo(wantedNoteId).findFirst();

      if (existing == null) {
        final note =
            NoteEntity()
              ..noteId = wantedNoteId
              ..updatedAt = now
              ..deletedAt = null
              ..archivedAt = null
              ..lastEditorDeviceId = editorDeviceId
              ..baseRevision = 0
              ..headRevision = 1
              ..isConflictCopy = false
              ..originNoteId = null;
        _applyDocSnapshotToNote(note, incomingDoc);
        await _db.noteEntitys.put(note);
        outcome = SaveNoteOutcome(
          note: note,
          isNew: true,
          createdConflictCopy: false,
          hasInlineConflict: false,
        );
        return;
      }

      var createdConflictCopy = false;
      if (expectedHeadRevision != null &&
          existing.headRevision != expectedHeadRevision) {
        final localSnapshot = NoteDocCodec.fromDocJson(
          docJson: existing.contentDocJson ?? '',
          fallbackMarkdown: existing.contentMd,
          fallbackTitle: existing.title,
        );
        final conflict =
            NoteEntity()
              ..noteId = newUuid()
              ..updatedAt = now
              ..deletedAt = null
              ..archivedAt = existing.archivedAt
              ..lastEditorDeviceId = existing.lastEditorDeviceId
              ..baseRevision = existing.headRevision
              ..headRevision = existing.headRevision + 1
              ..isConflictCopy = true
              ..originNoteId = existing.noteId;
        _applyDocSnapshotToNote(conflict, localSnapshot);
        await _db.noteEntitys.put(conflict);
        createdConflictCopy = true;
      }

      existing
        ..updatedAt = now
        ..deletedAt = null
        ..archivedAt = null
        ..lastEditorDeviceId = editorDeviceId
        ..baseRevision = existing.headRevision
        ..headRevision = existing.headRevision + 1
        ..isConflictCopy = false
        ..originNoteId = null;
      _applyDocSnapshotToNote(existing, incomingDoc);

      await _db.noteEntitys.put(existing);
      outcome = SaveNoteOutcome(
        note: existing,
        isNew: false,
        createdConflictCopy: createdConflictCopy,
        hasInlineConflict: false,
      );
    });

    return outcome;
  }

  /// 本地更新归档状态。
  ///
  /// - `archived = true`：归档；
  /// - `archived = false`：取消归档。
  Future<NoteEntity?> setArchivedStateLocal({
    required String noteId,
    required String editorDeviceId,
    required bool archived,
  }) async {
    NoteEntity? updated;
    await _db.writeTxn(() async {
      final existing =
          await _db.noteEntitys.where().noteIdEqualTo(noteId).findFirst();
      if (existing == null || existing.deletedAt != null) {
        return;
      }

      final now = DateTime.now().toUtc();
      existing
        ..archivedAt = archived ? now : null
        ..lastEditorDeviceId = editorDeviceId
        ..baseRevision = existing.headRevision
        ..headRevision = existing.headRevision + 1;
      await _db.noteEntitys.put(existing);
      updated = existing;
    });
    return updated;
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
        ..headRevision = existing.headRevision + 1;
      await _db.noteEntitys.put(existing);
    });
  }

  /// 本地恢复已软删除笔记。
  Future<NoteEntity?> restoreSoftDeletedLocalNote({
    required String noteId,
    required String editorDeviceId,
  }) async {
    NoteEntity? restored;
    await _db.writeTxn(() async {
      final existing =
          await _db.noteEntitys.where().noteIdEqualTo(noteId).findFirst();
      if (existing == null || existing.deletedAt == null) {
        return;
      }

      existing
        ..deletedAt = null
        ..lastEditorDeviceId = editorDeviceId
        ..baseRevision = existing.headRevision
        ..headRevision = existing.headRevision + 1;
      await _db.noteEntitys.put(existing);
      restored = existing;
    });
    return restored;
  }

  /// 应用远端笔记快照。
  ///
  /// 若无法基于 `baseRevision` 快进，则创建冲突副本。
  Future<ApplyRemoteOutcome> applyRemoteSnapshot(
    Map<String, dynamic> snapshot,
  ) async {
    final noteId = snapshot['noteId'] as String;
    final updatedAt = DateTime.parse(snapshot['updatedAt'] as String).toUtc();
    final deletedAtRaw = snapshot['deletedAt'] as String?;
    final deletedAt =
        deletedAtRaw == null ? null : DateTime.parse(deletedAtRaw).toUtc();
    final archivedAtRaw = snapshot['archivedAt'] as String?;
    final archivedAt =
        archivedAtRaw == null ? null : DateTime.parse(archivedAtRaw).toUtc();
    final lastEditorDeviceId = snapshot['lastEditorDeviceId'] as String;
    final baseRevision = snapshot['baseRevision'] as int;
    final headRevision = snapshot['headRevision'] as int;
    final incomingConflict = (snapshot['isConflictCopy'] as bool?) ?? false;
    final originNoteId = snapshot['originNoteId'] as String?;

    final schema = (snapshot['schemaVersion'] as int?) ?? 1;
    final incomingDoc = _snapshotToDoc(snapshot, schema);

    late ApplyRemoteOutcome outcome;

    await _db.writeTxn(() async {
      final local =
          await _db.noteEntitys.where().noteIdEqualTo(noteId).findFirst();
      if (local == null) {
        final fresh =
            NoteEntity()
              ..noteId = noteId
              ..updatedAt = updatedAt
              ..deletedAt = deletedAt
              ..archivedAt = archivedAt
              ..lastEditorDeviceId = lastEditorDeviceId
              ..baseRevision = baseRevision
              ..headRevision = headRevision
              ..isConflictCopy = incomingConflict
              ..originNoteId = originNoteId;
        _applyDocSnapshotToNote(fresh, incomingDoc);
        await _db.noteEntitys.put(fresh);
        outcome = ApplyRemoteOutcome(
          noteId: fresh.noteId,
          createdConflictCopy: false,
          hasInlineConflict: false,
        );
        return;
      }

      final canFastForward =
          incomingConflict || local.headRevision == baseRevision;
      if (canFastForward) {
        local
          ..updatedAt = updatedAt
          ..deletedAt = deletedAt
          ..archivedAt = archivedAt
          ..lastEditorDeviceId = lastEditorDeviceId
          ..baseRevision = baseRevision
          ..headRevision = headRevision
          ..isConflictCopy = incomingConflict
          ..originNoteId = originNoteId;
        _applyDocSnapshotToNote(local, incomingDoc);
        await _db.noteEntitys.put(local);
        outcome = ApplyRemoteOutcome(
          noteId: local.noteId,
          createdConflictCopy: false,
          hasInlineConflict: false,
        );
        return;
      }

      // 来自同一编辑设备时按远端覆盖，避免无意义冲突副本膨胀。
      final shouldRecoverFromRemote =
          local.lastEditorDeviceId == lastEditorDeviceId;
      if (shouldRecoverFromRemote) {
        local
          ..updatedAt = updatedAt
          ..deletedAt = deletedAt
          ..archivedAt = archivedAt
          ..lastEditorDeviceId = lastEditorDeviceId
          ..baseRevision = baseRevision
          ..headRevision = headRevision
          ..isConflictCopy = incomingConflict
          ..originNoteId = originNoteId;
        _applyDocSnapshotToNote(local, incomingDoc);
        await _db.noteEntitys.put(local);
        outcome = ApplyRemoteOutcome(
          noteId: local.noteId,
          createdConflictCopy: false,
          hasInlineConflict: false,
        );
        return;
      }

      final conflict =
          NoteEntity()
            ..noteId = newUuid()
            ..updatedAt = DateTime.now().toUtc()
            ..deletedAt = null
            ..archivedAt = archivedAt
            ..lastEditorDeviceId = lastEditorDeviceId
            ..baseRevision = baseRevision
            ..headRevision = headRevision
            ..isConflictCopy = true
            ..originNoteId = local.noteId;
      _applyDocSnapshotToNote(conflict, incomingDoc);
      await _db.noteEntitys.put(conflict);
      outcome = ApplyRemoteOutcome(
        noteId: local.noteId,
        createdConflictCopy: true,
        hasInlineConflict: false,
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
        final ghostSnapshot = NoteDocCodec.fromMarkdown('# Deleted Note\n');
        final ghost =
            NoteEntity()
              ..noteId = noteId
              ..updatedAt = deletedAt
              ..deletedAt = deletedAt
              ..archivedAt = null
              ..lastEditorDeviceId = editorDeviceId
              ..baseRevision = baseRevision
              ..headRevision = headRevision
              ..isConflictCopy = false
              ..originNoteId = null;
        _applyDocSnapshotToNote(ghost, ghostSnapshot);
        await _db.noteEntitys.put(ghost);
        return;
      }

      local
        ..deletedAt = deletedAt
        ..archivedAt = null
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
      'contentDocJson': note.contentDocJson,
      'contentMd': note.contentMd,
      'title': note.displayTitleCache ?? note.title,
      'displayTitleCache': note.displayTitleCache,
      'previewTextCache': note.previewTextCache,
      'contentFormat': note.contentFormat,
      'schemaVersion': note.schemaVersion == 0 ? 1 : note.schemaVersion,
      'docVersion': note.docVersion == 0 ? 1 : note.docVersion,
      'updatedAt': note.updatedAt.toUtc().toIso8601String(),
      'deletedAt': note.deletedAt?.toUtc().toIso8601String(),
      'archivedAt': note.archivedAt?.toUtc().toIso8601String(),
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

  NoteDocSnapshot _snapshotToDoc(Map<String, dynamic> snapshot, int schema) {
    if (schema >= 2) {
      final contentDocJson = snapshot['contentDocJson'] as String?;
      if (contentDocJson != null && contentDocJson.trim().isNotEmpty) {
        return NoteDocCodec.fromDocJson(docJson: contentDocJson);
      }
    }

    final title = (snapshot['title'] as String?) ?? NoteDocCodec.defaultHeading;
    final contentMd = (snapshot['contentMd'] as String?) ?? '';
    final markdown = NoteDocCodec.buildMarkdownFromLegacy(
      title: title,
      contentMd: contentMd,
    );
    return NoteDocCodec.fromMarkdown(markdown);
  }

  void _applyDocSnapshotToNote(NoteEntity note, NoteDocSnapshot snapshot) {
    note
      ..contentDocJson = snapshot.contentDocJson
      ..contentMd = snapshot.contentMd
      ..title = snapshot.displayTitle
      ..displayTitleCache = snapshot.displayTitle
      ..previewTextCache = snapshot.previewText
      ..contentFormat = snapshot.contentFormat
      ..docVersion = snapshot.schemaVersion
      ..schemaVersion = snapshot.schemaVersion;
  }

  Future<bool> _migrateSingleNote(NoteEntity note) async {
    final hasDocJson = (note.contentDocJson ?? '').trim().isNotEmpty;

    if (!hasDocJson) {
      final markdown = NoteDocCodec.buildMarkdownFromLegacy(
        title: note.title,
        contentMd: note.contentMd,
      );
      note
        ..contentMd = markdown
        ..title = NoteDocCodec.extractDisplayTitle(markdown)
        ..displayTitleCache = NoteDocCodec.extractDisplayTitle(markdown)
        ..previewTextCache = NoteDocCodec.extractPreviewText(markdown)
        ..contentFormat = NoteDocCodec.contentFormat
        ..schemaVersion = NoteDocCodec.schemaVersion
        ..docVersion = NoteDocCodec.schemaVersion;
      return true;
    }

    final markdown = note.contentMd.trim();
    final looksLikeDefaultHeadingOnly =
        markdown == '# 标题' || markdown == '# 标题\n' || markdown == '# Title';
    if (markdown.isNotEmpty && !looksLikeDefaultHeadingOnly) {
      note
        ..displayTitleCache = NoteDocCodec.extractDisplayTitle(note.contentMd)
        ..previewTextCache = NoteDocCodec.extractPreviewText(note.contentMd)
        ..contentFormat = NoteDocCodec.contentFormat
        ..schemaVersion =
            note.schemaVersion == 0
                ? NoteDocCodec.schemaVersion
                : note.schemaVersion
        ..docVersion =
            note.docVersion == 0 ? NoteDocCodec.schemaVersion : note.docVersion;
      return true;
    }

    final recovered = await _recoverFromLatestOpPayload(note.noteId);
    if (recovered == null) {
      return false;
    }
    _applyDocSnapshotToNote(note, recovered);
    return true;
  }

  Future<NoteDocSnapshot?> _recoverFromLatestOpPayload(String noteId) async {
    final logs =
        await _db.opLogEntitys
            .where()
            .filter()
            .noteIdEqualTo(noteId)
            .sortByLamportDesc()
            .findAll();
    for (final log in logs) {
      if (log.opType == 'delete') {
        continue;
      }
      try {
        final payload = jsonDecode(log.payloadJson);
        if (payload is! Map<String, dynamic>) {
          continue;
        }
        final schema = (payload['schemaVersion'] as int?) ?? 1;
        return _snapshotToDoc(payload, schema);
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
