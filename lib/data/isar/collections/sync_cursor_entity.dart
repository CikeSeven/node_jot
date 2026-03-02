import 'package:isar/isar.dart';

part 'sync_cursor_entity.g.dart';

/// 每个对端设备的增量游标实体。
@collection
class SyncCursorEntity {
  /// Isar 内部主键。
  Id isarId = Isar.autoIncrement;

  /// 对端设备 ID。
  @Index(unique: true, replace: true)
  late String peerDeviceId;

  late int lastLamportSeen;
  DateTime? lastSyncAt;
}
