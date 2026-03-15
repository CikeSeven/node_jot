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
    final changedNotes = <NoteEntity>[];
    for (final note in allNotes) {
      final changed = await _migrateSingleNote(note);
      if (!changed) {
        continue;
      }
      changedNotes.add(note);
    }
    if (changedNotes.isEmpty) {
      return;
    }
    await _db.writeTxn(() async {
      for (final note in changedNotes) {
        await _db.noteEntitys.put(note);
      }
    });
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
    final previousDocJson = (note.contentDocJson ?? '').trim();
    final previousContentMd = note.contentMd;
    final previousTitle = note.title;
    final previousDisplayTitle = note.displayTitleCache;
    final previousPreview = note.previewTextCache;
    final previousContentFormat = note.contentFormat;
    final previousSchemaVersion = note.schemaVersion;
    final previousDocVersion = note.docVersion;

    final fallbackMarkdown = NoteDocCodec.buildMarkdownFromLegacy(
      title: note.title,
      contentMd: note.contentMd,
    );

    final candidates = <_MigrationCandidate>[];
    _MigrationCandidate? currentDocCandidate;

    final docKind = _classifyDocJson(previousDocJson);
    if (previousDocJson.isNotEmpty) {
      try {
        final snapshot = NoteDocCodec.fromDocJson(
          docJson: previousDocJson,
          fallbackMarkdown: fallbackMarkdown,
          fallbackTitle: note.title,
        );
        currentDocCandidate = _MigrationCandidate(
          snapshot: snapshot,
          score: _scoreSnapshot(snapshot),
          priority: 40,
          lamport: null,
        );
        candidates.add(currentDocCandidate);
      } catch (_) {
        // ignore and fallback to other sources.
      }
    }

    final legacySnapshot = NoteDocCodec.fromMarkdown(fallbackMarkdown);
    candidates.add(
      _MigrationCandidate(
        snapshot: legacySnapshot,
        score: _scoreSnapshot(legacySnapshot),
        priority: 20,
        lamport: null,
      ),
    );

    final shouldTryOpRecovery =
        docKind != _MigrationDocKind.quillList ||
        (currentDocCandidate != null &&
            (_looksLikeTruncatedSingleHeading(currentDocCandidate.snapshot) ||
                _mayNeedFormattingRecovery(currentDocCandidate.snapshot)));
    if (shouldTryOpRecovery) {
      final opCandidates = await _recoverFromOpPayloads(
        note.noteId,
        limit: 120,
      );
      candidates.addAll(opCandidates);
    }

    final nextSnapshot = _pickMigrationCandidate(
      candidates: candidates,
      currentDocCandidate: currentDocCandidate,
      docKind: docKind,
    );

    _applyDocSnapshotToNote(note, nextSnapshot);

    return (note.contentDocJson ?? '').trim() != previousDocJson ||
        note.contentMd != previousContentMd ||
        note.title != previousTitle ||
        note.displayTitleCache != previousDisplayTitle ||
        note.previewTextCache != previousPreview ||
        note.contentFormat != previousContentFormat ||
        note.schemaVersion != previousSchemaVersion ||
        note.docVersion != previousDocVersion;
  }

  Future<List<_MigrationCandidate>> _recoverFromOpPayloads(
    String noteId, {
    int limit = 120,
  }) async {
    final logs =
        await _db.opLogEntitys
            .where()
            .filter()
            .noteIdEqualTo(noteId)
            .sortByLamportDesc()
            .findAll();
    final result = <_MigrationCandidate>[];
    final maxCount = limit < 1 ? 1 : limit;
    var rank = 0;

    for (final log in logs) {
      if (rank >= maxCount) {
        break;
      }
      if (log.opType == 'delete') {
        continue;
      }
      try {
        final payload = jsonDecode(log.payloadJson);
        if (payload is! Map<String, dynamic>) {
          continue;
        }
        final schema = (payload['schemaVersion'] as int?) ?? 1;
        final snapshot = _snapshotToDoc(payload, schema);
        result.add(
          _MigrationCandidate(
            snapshot: snapshot,
            score: _scoreSnapshot(snapshot),
            priority: 30,
            lamport: log.lamport,
          ),
        );
        rank += 1;
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  _MigrationDocKind _classifyDocJson(String contentDocJson) {
    if (contentDocJson.isEmpty) {
      return _MigrationDocKind.empty;
    }
    try {
      final raw = jsonDecode(contentDocJson);
      if (raw is List) {
        return _MigrationDocKind.quillList;
      }
      if (raw is Map<String, dynamic>) {
        return _MigrationDocKind.legacyMap;
      }
      return _MigrationDocKind.invalid;
    } catch (_) {
      return _MigrationDocKind.invalid;
    }
  }

  NoteDocSnapshot _pickMigrationCandidate({
    required List<_MigrationCandidate> candidates,
    required _MigrationCandidate? currentDocCandidate,
    required _MigrationDocKind docKind,
  }) {
    if (candidates.isEmpty) {
      return NoteDocCodec.fromMarkdown(NoteDocCodec.buildNewNoteMarkdown());
    }

    _MigrationCandidate best = candidates.first;
    for (final candidate in candidates.skip(1)) {
      if (_compareCandidate(candidate, best) > 0) {
        best = candidate;
      }
    }

    final current = currentDocCandidate;
    if (current == null) {
      return best.snapshot;
    }

    // 旧格式/损坏格式迁移：直接选最优候选。
    if (docKind != _MigrationDocKind.quillList) {
      return best.snapshot;
    }

    // 新格式兜底修复：仅在“疑似截断”为标题单行时，且存在明显更优候选时替换。
    if (_looksLikeTruncatedSingleHeading(current.snapshot) &&
        _compareCandidate(best, current) > 1200) {
      return best.snapshot;
    }

    if (_canUpgradeFormatting(current, best)) {
      return best.snapshot;
    }

    return current.snapshot;
  }

  bool _canUpgradeFormatting(
    _MigrationCandidate current,
    _MigrationCandidate best,
  ) {
    final currentBlockScore = _quillBlockStyleScore(
      current.snapshot.contentDocJson,
    );
    final bestBlockScore = _quillBlockStyleScore(best.snapshot.contentDocJson);
    if (bestBlockScore <= currentBlockScore) {
      return false;
    }

    final currentSignature = _plainTextSignature(current.snapshot.contentMd);
    final bestSignature = _plainTextSignature(best.snapshot.contentMd);
    if (currentSignature.isEmpty ||
        bestSignature.isEmpty ||
        currentSignature != bestSignature) {
      return false;
    }

    return true;
  }

  int _compareCandidate(_MigrationCandidate a, _MigrationCandidate b) {
    final scoreDiff = a.score - b.score;
    if (scoreDiff != 0) {
      return scoreDiff;
    }
    final priorityDiff = a.priority - b.priority;
    if (priorityDiff != 0) {
      return priorityDiff;
    }
    final lamportA = a.lamport ?? -1;
    final lamportB = b.lamport ?? -1;
    return lamportA - lamportB;
  }

  bool _looksLikeTruncatedSingleHeading(NoteDocSnapshot snapshot) {
    final lines = snapshot.contentMd
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.length != 1) {
      return false;
    }
    return lines.first.startsWith('# ');
  }

  int _scoreSnapshot(NoteDocSnapshot snapshot) {
    final lines = snapshot.contentMd
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final nonWhitespaceLength =
        snapshot.contentMd.replaceAll(RegExp(r'\s+'), '').length;
    final headingLineCount =
        lines.where((line) => line.startsWith('# ')).length;
    final bodyLineCount = lines.length - headingLineCount;
    final bodyChars =
        lines
            .where((line) => !line.startsWith('# '))
            .join()
            .replaceAll(RegExp(r'\s+'), '')
            .length;
    final blockScore = _quillBlockStyleScore(snapshot.contentDocJson);

    return nonWhitespaceLength +
        lines.length * 1000 +
        bodyLineCount * 500 +
        bodyChars * 2 +
        blockScore * 600;
  }

  bool _mayNeedFormattingRecovery(NoteDocSnapshot snapshot) {
    final lines = snapshot.contentMd
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.length <= 1) {
      return false;
    }

    final blockScore = _quillBlockStyleScore(snapshot.contentDocJson);
    if (blockScore > 0) {
      return false;
    }

    final bodyLines = lines.where((line) => !line.startsWith('# '));
    return bodyLines.isNotEmpty;
  }

  int _quillBlockStyleScore(String contentDocJson) {
    if (contentDocJson.trim().isEmpty) {
      return 0;
    }
    try {
      final raw = jsonDecode(contentDocJson);
      if (raw is! List) {
        return 0;
      }

      var score = 0;
      for (final op in raw) {
        if (op is! Map) {
          continue;
        }
        final insert = op['insert'];
        if (insert != '\n') {
          continue;
        }
        final attrs = op['attributes'];
        if (attrs is! Map) {
          continue;
        }
        if (attrs['header'] != null) {
          score += 2;
        }
        final listType = attrs['list'];
        if (listType == 'checked' || listType == 'unchecked') {
          score += 4;
        } else if (listType != null) {
          score += 3;
        }
        if (attrs['blockquote'] != null) {
          score += 3;
        }
        if (attrs['code-block'] != null) {
          score += 3;
        }
      }
      return score;
    } catch (_) {
      return 0;
    }
  }

  String _plainTextSignature(String markdown) {
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final normalized = lines
        .map((line) {
          var text = line.trimLeft();
          text = text.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
          text = text.replaceFirst(RegExp(r'^-\s\[(?: |x|X)\]\s+'), '');
          text = text.replaceFirst(RegExp(r'^[-*+]\s+'), '');
          text = text.replaceFirst(RegExp(r'^\d+\.\s+'), '');
          text = text.replaceFirst(RegExp(r'^>\s*'), '');
          return text.trim();
        })
        .join('\n');
    return normalized.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }
}

enum _MigrationDocKind { empty, quillList, legacyMap, invalid }

class _MigrationCandidate {
  const _MigrationCandidate({
    required this.snapshot,
    required this.score,
    required this.priority,
    required this.lamport,
  });

  final NoteDocSnapshot snapshot;
  final int score;
  final int priority;
  final int? lamport;
}
