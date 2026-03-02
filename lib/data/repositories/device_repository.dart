import 'package:isar/isar.dart';

import '../isar/collections/device_entity.dart';

/// 设备仓储。
///
/// 管理发现设备与已配对设备的本地持久化。
class DeviceRepository {
  DeviceRepository(this._db);

  final Isar _db;

  /// 监听已信任设备列表。
  Stream<List<DeviceEntity>> watchTrustedDevices() {
    return _db.deviceEntitys
        .where()
        .filter()
        .trustedEqualTo(true)
        .sortByDisplayName()
        .watch(fireImmediately: true);
  }

  /// 按设备 ID 查询。
  Future<DeviceEntity?> getByDeviceId(String deviceId) {
    return _db.deviceEntitys.where().deviceIdEqualTo(deviceId).findFirst();
  }

  /// 更新或插入“已发现但未配对”的设备信息。
  Future<void> upsertSeenDevice({
    required String deviceId,
    required String displayName,
    required String host,
    required int port,
    required String publicKey,
  }) async {
    await _db.writeTxn(() async {
      final existing =
          await _db.deviceEntitys.where().deviceIdEqualTo(deviceId).findFirst();
      if (existing == null) {
        final item =
            DeviceEntity()
              ..deviceId = deviceId
              ..displayName = displayName
              ..host = host
              ..port = port
              ..publicKey = publicKey
              ..trusted = false
              ..lastSeenAt = DateTime.now().toUtc();
        await _db.deviceEntitys.put(item);
        return;
      }

      existing
        ..displayName = existing.trusted ? existing.displayName : displayName
        ..host = host
        ..port = port
        ..publicKey = publicKey
        ..lastSeenAt = DateTime.now().toUtc();
      await _db.deviceEntitys.put(existing);
    });
  }

  /// 更新或插入“已配对”设备信息，并持久化共享密钥。
  Future<void> upsertTrustedDevice({
    required String deviceId,
    required String displayName,
    required String host,
    required int port,
    required String publicKey,
    required String sharedKey,
  }) async {
    await _db.writeTxn(() async {
      final existing =
          await _db.deviceEntitys.where().deviceIdEqualTo(deviceId).findFirst();
      if (existing == null) {
        final item =
            DeviceEntity()
              ..deviceId = deviceId
              ..displayName = displayName
              ..host = host
              ..port = port
              ..publicKey = publicKey
              ..sharedKey = sharedKey
              ..trusted = true
              ..pairedAt = DateTime.now().toUtc()
              ..lastSeenAt = DateTime.now().toUtc();
        await _db.deviceEntitys.put(item);
        return;
      }

      existing
        ..displayName = existing.trusted ? existing.displayName : displayName
        ..host = host
        ..port = port
        ..publicKey = publicKey
        ..sharedKey = sharedKey
        ..trusted = true
        ..pairedAt = existing.pairedAt ?? DateTime.now().toUtc()
        ..lastSeenAt = DateTime.now().toUtc();
      await _db.deviceEntitys.put(existing);
    });
  }

  /// 更新已配对设备备注（复用 displayName 展示字段）。
  Future<void> updateTrustedDeviceRemark({
    required String deviceId,
    required String remark,
  }) async {
    await _db.writeTxn(() async {
      final existing =
          await _db.deviceEntitys.where().deviceIdEqualTo(deviceId).findFirst();
      if (existing == null || !existing.trusted) {
        return;
      }
      final trimmed = remark.trim();
      if (trimmed.isEmpty) {
        return;
      }
      existing.displayName = trimmed;
      await _db.deviceEntitys.put(existing);
    });
  }

  /// 删除指定设备（解除信任关系）。
  Future<void> deleteDevice(String deviceId) async {
    await _db.writeTxn(() async {
      final existing =
          await _db.deviceEntitys.where().deviceIdEqualTo(deviceId).findFirst();
      if (existing == null) {
        return;
      }
      await _db.deviceEntitys.delete(existing.isarId);
    });
  }

  /// 清空所有已配对设备记录。
  Future<void> clearTrustedDevices() async {
    await _db.writeTxn(() async {
      final trusted =
          await _db.deviceEntitys.where().filter().trustedEqualTo(true).findAll();
      for (final device in trusted) {
        await _db.deviceEntitys.delete(device.isarId);
      }
    });
  }
}
