import 'dart:convert';

/// 同步操作日志模型（Lamport 顺序）。
///
/// 每条操作都可独立序列化传输，并用于跨端重放。
class SyncOperation {
  const SyncOperation({
    required this.opId,
    required this.lamport,
    required this.deviceId,
    required this.noteId,
    required this.opType,
    required this.payload,
    required this.createdAt,
  });

  final String opId;
  final int lamport;
  final String deviceId;
  final String noteId;
  final String opType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  /// 转为可序列化的 Map，用于网络传输与持久化。
  Map<String, dynamic> toMap() {
    return {
      'opId': opId,
      'lamport': lamport,
      'deviceId': deviceId,
      'noteId': noteId,
      'opType': opType,
      'payload': payload,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  /// 仅序列化业务负载部分。
  String toPayloadJson() {
    return jsonEncode(payload);
  }

  /// 从 Map 反序列化同步操作。
  factory SyncOperation.fromMap(Map<String, dynamic> map) {
    return SyncOperation(
      opId: map['opId'] as String,
      lamport: map['lamport'] as int,
      deviceId: map['deviceId'] as String,
      noteId: map['noteId'] as String,
      opType: map['opType'] as String,
      payload: (map['payload'] as Map).cast<String, dynamic>(),
      createdAt: DateTime.parse(map['createdAt'] as String).toUtc(),
    );
  }
}
