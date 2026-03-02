/// 局域网发现阶段的临时设备模型。
///
/// 该模型来自 UDP 发现报文，不代表已完成配对或信任。
class DiscoveredDevice {
  const DiscoveredDevice({
    required this.deviceId,
    required this.displayName,
    required this.host,
    required this.port,
    required this.publicKey,
    required this.lastSeen,
  });

  final String deviceId;
  final String displayName;
  final String host;
  final int port;
  final String publicKey;
  final DateTime lastSeen;

  /// 复制对象并替换部分字段。
  DiscoveredDevice copyWith({
    String? displayName,
    String? host,
    int? port,
    String? publicKey,
    DateTime? lastSeen,
  }) {
    return DiscoveredDevice(
      deviceId: deviceId,
      displayName: displayName ?? this.displayName,
      host: host ?? this.host,
      port: port ?? this.port,
      publicKey: publicKey ?? this.publicKey,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
