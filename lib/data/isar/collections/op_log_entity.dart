import 'package:isar/isar.dart';

part 'op_log_entity.g.dart';

/// 同步操作日志实体。
///
/// 记录每次本地或远端操作，支持增量同步与幂等去重。
@collection
class OpLogEntity {
  /// Isar 内部主键。
  Id isarId = Isar.autoIncrement;

  /// 同步操作唯一 ID。
  @Index(unique: true, replace: true)
  late String opId;

  /// Lamport 逻辑时钟，保证跨端排序。
  @Index()
  late int lamport;

  late String deviceId;
  late String noteId;
  late String opType;
  late String payloadJson;
  late DateTime createdAt;
}
