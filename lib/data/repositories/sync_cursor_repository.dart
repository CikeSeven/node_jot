import 'package:isar/isar.dart';

import '../isar/collections/sync_cursor_entity.dart';

/// 同步游标仓储。
///
/// 维护“我已经处理到对端哪个 Lamport”这一状态。
class SyncCursorRepository {
  SyncCursorRepository(this._db);

  final Isar _db;

  /// 获取指定对端设备的最近已处理 Lamport。
  Future<int> getLastLamportSeen(String peerDeviceId) async {
    final cursor =
        await _db.syncCursorEntitys
            .where()
            .peerDeviceIdEqualTo(peerDeviceId)
            .findFirst();
    return cursor?.lastLamportSeen ?? 0;
  }

  /// 保存对端游标。
  Future<void> saveCursor(String peerDeviceId, int lamport) async {
    await _db.writeTxn(() async {
      final existing =
          await _db.syncCursorEntitys
              .where()
              .peerDeviceIdEqualTo(peerDeviceId)
              .findFirst();
      if (existing == null) {
        final item =
            SyncCursorEntity()
              ..peerDeviceId = peerDeviceId
              ..lastLamportSeen = lamport
              ..lastSyncAt = DateTime.now().toUtc();
        await _db.syncCursorEntitys.put(item);
        return;
      }

      existing
        ..lastLamportSeen = lamport
        ..lastSyncAt = DateTime.now().toUtc();
      await _db.syncCursorEntitys.put(existing);
    });
  }
}
