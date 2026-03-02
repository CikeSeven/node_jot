import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/id.dart';
import '../models/local_device_profile.dart';
import 'crypto_service.dart';

/// 本机设备身份服务。
///
/// 首次启动生成设备 ID 与密钥对，后续从本地持久化恢复。
class LocalDeviceService {
  LocalDeviceService._({
    required SharedPreferences prefs,
    required LocalDeviceProfile profile,
  }) : _prefs = prefs,
       _profile = profile;

  static const _keyDeviceId = 'local.device.id';
  static const _keyDisplayName = 'local.device.display_name';
  static const _keyPublicKey = 'local.device.public_key';
  static const _keyPrivateKey = 'local.device.private_key';

  final SharedPreferences _prefs;
  LocalDeviceProfile _profile;

  /// 当前本机身份快照。
  LocalDeviceProfile get profile => _profile;

  /// 创建服务并初始化本机身份。
  static Future<LocalDeviceService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final crypto = CryptoService();

    var deviceId = prefs.getString(_keyDeviceId);
    var displayName = prefs.getString(_keyDisplayName);
    var publicKey = prefs.getString(_keyPublicKey);
    var privateKey = prefs.getString(_keyPrivateKey);

    if (deviceId == null ||
        displayName == null ||
        publicKey == null ||
        privateKey == null) {
      final pair = await crypto.generateX25519KeyPair();
      deviceId = newUuid();
      displayName = 'NodeJot-${deviceId.substring(0, 4)}';
      publicKey = pair['publicKey'];
      privateKey = pair['privateKey'];

      await prefs.setString(_keyDeviceId, deviceId);
      await prefs.setString(_keyDisplayName, displayName);
      await prefs.setString(_keyPublicKey, publicKey!);
      await prefs.setString(_keyPrivateKey, privateKey!);
    }

    final profile = LocalDeviceProfile(
      deviceId: deviceId,
      displayName: displayName,
      publicKey: publicKey,
      privateKey: privateKey,
    );

    return LocalDeviceService._(prefs: prefs, profile: profile);
  }

  /// 更新设备展示名并持久化。
  Future<void> updateDisplayName(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }

    _profile = _profile.copyWith(displayName: trimmed);
    await _prefs.setString(_keyDisplayName, trimmed);
  }
}
