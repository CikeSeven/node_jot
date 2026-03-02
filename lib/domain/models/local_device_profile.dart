/// 本机设备身份信息。
///
/// 包含设备标识、展示名与配对/加密所需密钥材料。
class LocalDeviceProfile {
  const LocalDeviceProfile({
    required this.deviceId,
    required this.displayName,
    required this.publicKey,
    required this.privateKey,
  });

  final String deviceId;
  final String displayName;
  final String publicKey;
  final String privateKey;

  /// 返回带新展示名的副本。
  LocalDeviceProfile copyWith({String? displayName}) {
    return LocalDeviceProfile(
      deviceId: deviceId,
      displayName: displayName ?? this.displayName,
      publicKey: publicKey,
      privateKey: privateKey,
    );
  }
}
