import 'package:isar/isar.dart';

part 'device_entity.g.dart';

/// 已发现/已配对设备实体。
///
/// `trusted=true` 表示已完成配对并保存共享密钥。
@collection
class DeviceEntity {
  /// Isar 内部主键。
  Id isarId = Isar.autoIncrement;

  /// 设备唯一标识。
  @Index(unique: true, replace: true)
  late String deviceId;

  late String displayName;
  late String host;
  late int port;
  late String publicKey;
  String? sharedKey;
  DateTime? pairedAt;
  bool trusted = false;
  DateTime? lastSeenAt;
}
