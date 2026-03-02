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
  static final RegExp _autoTitlePattern = RegExp(r'^标题(\d+)$');

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

  /// 获取新建笔记默认标题的下一个序号。
  ///
  /// 规则：扫描未删除笔记中形如“标题N”的标题，返回最大 N + 1。
  /// 若不存在匹配项，则返回 1。
  Future<int> getNextAutoTitleIndex() async {
    final notes =
        await _db.noteEntitys.where().filter().deletedAtIsNull().findAll();
    var maxIndex = 0;

    for (final note in notes) {
      final match = _autoTitlePattern.firstMatch(note.title.trim());
      if (match == null) {
        continue;
      }
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value > maxIndex) {
        maxIndex = value;
      }
    }

    return maxIndex + 1;
  }

  /// 保存本地编辑。
  ///
  /// - 新笔记：创建 `headRevision=1`；
  /// - 旧笔记：正常快进 revision；
  /// - revision 不匹配：写入 Git 风格内联冲突块，避免覆盖现有内容。
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
              ..archivedAt = null
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
          hasInlineConflict: false,
        );
        return;
      }

      if (expectedHeadRevision != null &&
          existing.headRevision != expectedHeadRevision) {
        existing
          ..title = normalizedTitle
          ..contentMd = _buildGitConflictContent(
            localContent: _stripOuterConflictMarkers(existing.contentMd),
            remoteContent: contentMd,
          )
          ..updatedAt = now
          ..deletedAt = null
          ..archivedAt = null
          ..lastEditorDeviceId = editorDeviceId
          ..baseRevision = existing.headRevision
          ..headRevision = existing.headRevision + 1
          ..isConflictCopy = false
          ..originNoteId = null;
        await _db.noteEntitys.put(existing);
        outcome = SaveNoteOutcome(
          note: existing,
          isNew: false,
          createdConflictCopy: false,
          hasInlineConflict: true,
        );
        return;
      }

      existing
        ..title = normalizedTitle
        ..contentMd = contentMd
        ..updatedAt = now
        ..deletedAt = null
        ..archivedAt = null
        ..lastEditorDeviceId = editorDeviceId
        ..baseRevision = existing.headRevision
        ..headRevision = existing.headRevision + 1;

      await _db.noteEntitys.put(existing);
      outcome = SaveNoteOutcome(
        note: existing,
        isNew: false,
        createdConflictCopy: false,
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
        ..updatedAt = now
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
        ..headRevision = existing.headRevision + 1
        ..updatedAt = now;
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

      final now = DateTime.now().toUtc();
      existing
        ..deletedAt = null
        ..updatedAt = now
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
  /// 若无法基于 `baseRevision` 快进，则写入 Git 风格内联冲突块。
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
    final archivedAtRaw = snapshot['archivedAt'] as String?;
    final archivedAt =
        archivedAtRaw == null ? null : DateTime.parse(archivedAtRaw).toUtc();
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
              ..archivedAt = archivedAt
              ..lastEditorDeviceId = lastEditorDeviceId
              ..baseRevision = baseRevision
              ..headRevision = headRevision
              ..isConflictCopy = incomingConflict
              ..originNoteId = originNoteId;
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
          ..title = title
          ..contentMd = content
          ..updatedAt = updatedAt
          ..deletedAt = deletedAt
          ..archivedAt = archivedAt
          ..lastEditorDeviceId = lastEditorDeviceId
          ..baseRevision = baseRevision
          ..headRevision = headRevision
          ..isConflictCopy = incomingConflict
          ..originNoteId = originNoteId;
        await _db.noteEntitys.put(local);
        outcome = ApplyRemoteOutcome(
          noteId: local.noteId,
          createdConflictCopy: false,
          hasInlineConflict: false,
        );
        return;
      }

      // 若来自同一编辑设备，说明是远端后续版本到达但本地 revision 游标偏移，
      // 直接按远端覆盖恢复一致性，避免重复嵌套冲突标记。
      final shouldRecoverFromRemote =
          local.lastEditorDeviceId == lastEditorDeviceId;
      if (shouldRecoverFromRemote) {
        local
          ..title = title
          ..contentMd = content
          ..updatedAt = updatedAt
          ..deletedAt = deletedAt
          ..archivedAt = archivedAt
          ..lastEditorDeviceId = lastEditorDeviceId
          ..baseRevision = baseRevision
          ..headRevision = headRevision
          ..isConflictCopy = incomingConflict
          ..originNoteId = originNoteId;
        await _db.noteEntitys.put(local);
        outcome = ApplyRemoteOutcome(
          noteId: local.noteId,
          createdConflictCopy: false,
          hasInlineConflict: false,
        );
        return;
      }

      local
        ..title = title
        ..contentMd = _buildGitConflictContent(
          localContent: _stripOuterConflictMarkers(local.contentMd),
          remoteContent: content,
        )
        ..updatedAt = DateTime.now().toUtc()
        ..deletedAt = null
        ..archivedAt = archivedAt
        ..lastEditorDeviceId = lastEditorDeviceId
        ..baseRevision = baseRevision
        ..headRevision = headRevision
        ..isConflictCopy = false
        ..originNoteId = null;
      await _db.noteEntitys.put(local);
      outcome = ApplyRemoteOutcome(
        noteId: local.noteId,
        createdConflictCopy: false,
        hasInlineConflict: true,
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
              ..archivedAt = null
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
        ..archivedAt = null
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

  /// 生成 Git 风格的内联冲突内容。
  String _buildGitConflictContent({
    required String localContent,
    required String remoteContent,
  }) {
    return '<<<<<<< LOCAL\n'
        '$localContent\n'
        '=======\n'
        '$remoteContent\n'
        '>>>>>>> REMOTE';
  }

  String _stripOuterConflictMarkers(String content) {
    final trimmed = content.trim();
    if (!trimmed.startsWith('<<<<<<< LOCAL') ||
        !trimmed.contains('\n=======\n') ||
        !trimmed.endsWith('>>>>>>> REMOTE')) {
      return content;
    }
    final start = '<<<<<<< LOCAL\n'.length;
    final mid = trimmed.indexOf('\n=======\n');
    if (mid <= start) {
      return content;
    }
    return trimmed.substring(start, mid);
  }
}
