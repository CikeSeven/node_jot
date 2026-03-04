import 'dart:convert';

import 'package:isar/isar.dart';

import '../../core/utils/id.dart';
import '../../core/utils/note_doc_codec.dart';
import '../isar/collections/note_entity.dart';
import '../isar/collections/op_log_entity.dart';

/// 本地保存笔记后的结果。
class SaveNoteOutcome {
  const SaveNoteOutcome({required this.note, required this.isNew});

  final NoteEntity note;
  final bool isNew;
}

/// 应用远端快照后的结果。
class ApplyRemoteOutcome {
  const ApplyRemoteOutcome({required this.noteId, required this.applied});

  final String noteId;
  final bool applied;
}

/// 笔记仓储。
///
/// 负责笔记 CRUD 与远端快照落库。
class NoteRepository {
  NoteRepository(this._db);

  final Isar _db;

  /// 监听未删除笔记（按更新时间倒序）。
  Stream<List<NoteEntity>> watchActiveNotes() {
    return _db.noteEntitys.watchLazy(fireImmediately: true).asyncMap((_) {
      return _db.noteEntitys
          .where()
          .filter()
          .deletedAtIsNull()
          .archivedAtIsNull()
          .sortByUpdatedAtDesc()
          .findAll();
    });
  }

  /// 按关键词监听未删除笔记（标题 + 正文）。
  ///
  /// 说明：
  /// - 关键词为空时，直接回退到 [watchActiveNotes]；
  /// - 非空时使用 Isar 的 `contains` 查询方法分别检索标题和正文，
  ///   再按 `noteId` 去重后按更新时间倒序返回。
  Stream<List<NoteEntity>> watchActiveNotesByKeyword(String keyword) {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return watchActiveNotes();
    }

    return _db.noteEntitys.watchLazy(fireImmediately: true).asyncMap((_) async {
      final titleHits =
          await _db.noteEntitys
              .where()
              .filter()
              .deletedAtIsNull()
              .archivedAtIsNull()
              .titleContains(normalized, caseSensitive: false)
              .findAll();

      final contentHits =
          await _db.noteEntitys
              .where()
              .filter()
              .deletedAtIsNull()
              .archivedAtIsNull()
              .contentMdContains(normalized, caseSensitive: false)
              .findAll();

      final dedup = <String, NoteEntity>{};
      for (final note in titleHits) {
        dedup[note.noteId] = note;
      }
      for (final note in contentHits) {
        dedup[note.noteId] = note;
      }

      final result = dedup.values.toList(growable: false)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return result;
    });
  }

  /// 监听已归档且未删除的笔记（按更新时间倒序）。
  Stream<List<NoteEntity>> watchArchivedNotes() {
    return _db.noteEntitys.watchLazy(fireImmediately: true).asyncMap((_) {
      return _db.noteEntitys
          .where()
          .filter()
          .deletedAtIsNull()
          .archivedAtIsNotNull()
          .sortByUpdatedAtDesc()
          .findAll();
    });
  }

  /// 监听冲突副本笔记。
  Stream<List<NoteEntity>> watchConflictNotes() {
    return _db.noteEntitys.watchLazy(fireImmediately: true).asyncMap((_) {
      return _db.noteEntitys
          .where()
          .filter()
          .isConflictCopyEqualTo(true)
          .deletedAtIsNull()
          .archivedAtIsNull()
          .sortByUpdatedAtDesc()
          .findAll();
    });
  }

  /// 按业务 ID 查询笔记。
  Future<NoteEntity?> getByNoteId(String noteId) {
    return _db.noteEntitys.where().noteIdEqualTo(noteId).findFirst();
  }

  /// 监听单条笔记（按业务 ID）。
  ///
  /// 说明：Isar 当前无 `noteId` 级对象监听，这里使用 `watchLazy + query` 兜底。
  Stream<NoteEntity?> watchNoteById(String noteId) {
    return _db.noteEntitys.watchLazy(fireImmediately: true).asyncMap((_) {
      return _db.noteEntitys.where().noteIdEqualTo(noteId).findFirst();
    });
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

  /// 清理历史冲突副本。
  ///
  /// 返回删除的记录数量。
  Future<int> purgeConflictCopies() async {
    final conflicts =
        await _db.noteEntitys
            .where()
            .filter()
            .isConflictCopyEqualTo(true)
            .findAll();
    if (conflicts.isEmpty) {
      return 0;
    }

    await _db.writeTxn(() async {
      for (final note in conflicts) {
        await _db.noteEntitys.delete(note.isarId);
      }
    });
    return conflicts.length;
  }

  /// 保存本地编辑。
  ///
  /// - 新笔记：创建 `headRevision=1`；
  /// - 旧笔记：正常快进 revision。
  Future<SaveNoteOutcome> saveLocalNote({
    required String contentDocJson,
    required String editorDeviceId,
    String? noteId,
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
        outcome = SaveNoteOutcome(note: note, isNew: true);
        return;
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
      outcome = SaveNoteOutcome(note: existing, isNew: false);
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
    final baseRevision = snapshot['baseRevision'] as int? ?? 0;
    final headRevision = snapshot['headRevision'] as int? ?? 0;

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
              ..isConflictCopy = false
              ..originNoteId = null;
        _applyDocSnapshotToNote(fresh, incomingDoc);
        await _db.noteEntitys.put(fresh);
        outcome = ApplyRemoteOutcome(noteId: fresh.noteId, applied: true);
        return;
      }

      final shouldApplyRemote = _shouldApplyRemoteSnapshot(
        localUpdatedAt: local.updatedAt,
        localHeadRevision: local.headRevision,
        localLastEditorDeviceId: local.lastEditorDeviceId,
        remoteUpdatedAt: updatedAt,
        remoteHeadRevision: headRevision,
        remoteLastEditorDeviceId: lastEditorDeviceId,
      );
      if (!shouldApplyRemote) {
        outcome = ApplyRemoteOutcome(noteId: local.noteId, applied: false);
        return;
      }

      local
        ..updatedAt = updatedAt
        ..deletedAt = deletedAt
        ..archivedAt = archivedAt
        ..lastEditorDeviceId = lastEditorDeviceId
        ..baseRevision = baseRevision
        ..headRevision = headRevision
        ..isConflictCopy = false
        ..originNoteId = null;
      _applyDocSnapshotToNote(local, incomingDoc);
      await _db.noteEntitys.put(local);
      outcome = ApplyRemoteOutcome(noteId: local.noteId, applied: true);
    });

    return outcome;
  }

  bool _shouldApplyRemoteSnapshot({
    required DateTime localUpdatedAt,
    required int localHeadRevision,
    required String localLastEditorDeviceId,
    required DateTime remoteUpdatedAt,
    required int remoteHeadRevision,
    required String remoteLastEditorDeviceId,
  }) {
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      return true;
    }
    if (remoteUpdatedAt.isBefore(localUpdatedAt)) {
      return false;
    }

    if (remoteHeadRevision > localHeadRevision) {
      return true;
    }
    if (remoteHeadRevision < localHeadRevision) {
      return false;
    }

    return remoteLastEditorDeviceId.compareTo(localLastEditorDeviceId) > 0;
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
        markdown == '# 标题' ||
        markdown == '# 标题\n' ||
        markdown == '# 未命名笔记' ||
        markdown == '# 未命名笔记\n' ||
        markdown == '# Title';
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
