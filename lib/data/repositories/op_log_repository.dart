import 'dart:convert';

import 'package:isar/isar.dart';

import '../../domain/models/sync_operation.dart';
import '../isar/collections/op_log_entity.dart';

/// 操作日志仓储。
///
/// 保证操作幂等写入，并支持按 Lamport 游标增量读取。
class OpLogRepository {
  OpLogRepository(this._db);

  final Isar _db;

  /// 判断操作是否已存在（用于幂等去重）。
  Future<bool> hasOp(String opId) async {
    final existing =
        await _db.opLogEntitys.where().opIdEqualTo(opId).findFirst();
    return existing != null;
  }

  /// 获取当前最大的 Lamport 值。
  Future<int> getMaxLamport() async {
    final latest =
        await _db.opLogEntitys.where().sortByLamportDesc().findFirst();
    return latest?.lamport ?? 0;
  }

  /// 追加一条同步操作。
  ///
  /// 若 opId 已存在则直接忽略，确保重复消息不会产生重复落库。
  Future<void> appendOperation(SyncOperation op) async {
    await _db.writeTxn(() async {
      final exists =
          await _db.opLogEntitys.where().opIdEqualTo(op.opId).findFirst();
      if (exists != null) {
        return;
      }

      final entry =
          OpLogEntity()
            ..opId = op.opId
            ..lamport = op.lamport
            ..deviceId = op.deviceId
            ..noteId = op.noteId
            ..opType = op.opType
            ..payloadJson = jsonEncode(op.payload)
            ..createdAt = op.createdAt;
      await _db.opLogEntitys.put(entry);
    });
  }

  /// 获取指定 Lamport 之后的增量操作。
  Future<List<SyncOperation>> getOpsAfter(
    int lamport, {
    int limit = 500,
  }) async {
    final items =
        await _db.opLogEntitys
            .where()
            .filter()
            .lamportGreaterThan(lamport)
            .sortByLamport()
            .findAll();

    final sliced = items.take(limit);
    return sliced
        .map(
          (e) => SyncOperation(
            opId: e.opId,
            lamport: e.lamport,
            deviceId: e.deviceId,
            noteId: e.noteId,
            opType: e.opType,
            payload: jsonDecode(e.payloadJson) as Map<String, dynamic>,
            createdAt: e.createdAt,
          ),
        )
        .toList();
  }
}
