import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用运行设置服务。
///
/// 持久化保存用户对连接策略和同步策略的偏好。
class AppSettingsService {
  AppSettingsService._({
    required SharedPreferences prefs,
    required bool oneTimeConnection,
    required bool autoSync,
    required bool fixedPairingCodeEnabled,
    String? fixedPairingCode,
  }) : _prefs = prefs,
       oneTimeConnectionNotifier = ValueNotifier<bool>(oneTimeConnection),
       autoSyncNotifier = ValueNotifier<bool>(autoSync),
       fixedPairingCodeEnabledNotifier = ValueNotifier<bool>(
         fixedPairingCodeEnabled,
       ),
       _fixedPairingCode = _normalizePairingCode(fixedPairingCode);

  static const _keyOneTimeConnection = 'app.settings.one_time_connection';
  static const _keyAutoSync = 'app.settings.auto_sync';
  static const _keyFixedPairingCodeEnabled =
      'app.settings.fixed_pairing_code_enabled';
  static const _keyFixedPairingCode = 'app.settings.fixed_pairing_code';

  final SharedPreferences _prefs;
  final ValueNotifier<bool> oneTimeConnectionNotifier;
  final ValueNotifier<bool> autoSyncNotifier;
  final ValueNotifier<bool> fixedPairingCodeEnabledNotifier;
  String? _fixedPairingCode;

  /// 固定配对码（4 位数字），未设置时为 null。
  String? get fixedPairingCode => _fixedPairingCode;

  static Future<AppSettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final oneTime = prefs.getBool(_keyOneTimeConnection) ?? false;
    final autoSync = prefs.getBool(_keyAutoSync) ?? false;
    final fixedPairingCodeEnabled =
        prefs.getBool(_keyFixedPairingCodeEnabled) ?? false;
    final fixedPairingCode = prefs.getString(_keyFixedPairingCode);
    return AppSettingsService._(
      prefs: prefs,
      oneTimeConnection: oneTime,
      autoSync: autoSync,
      fixedPairingCodeEnabled: fixedPairingCodeEnabled,
      fixedPairingCode: fixedPairingCode,
    );
  }

  Future<void> setOneTimeConnection(bool enabled) async {
    oneTimeConnectionNotifier.value = enabled;
    await _prefs.setBool(_keyOneTimeConnection, enabled);
  }

  Future<void> setAutoSync(bool enabled) async {
    autoSyncNotifier.value = enabled;
    await _prefs.setBool(_keyAutoSync, enabled);
  }

  /// 开启/关闭固定配对码。
  ///
  /// 开启时若传入了当前有效配对码，会立即持久化，确保下次启动仍保持一致。
  Future<void> setFixedPairingCodeEnabled(
    bool enabled, {
    String? currentPairingCode,
  }) async {
    fixedPairingCodeEnabledNotifier.value = enabled;
    await _prefs.setBool(_keyFixedPairingCodeEnabled, enabled);

    if (!enabled) {
      return;
    }

    final normalizedCurrent = _normalizePairingCode(currentPairingCode);
    if (normalizedCurrent != null) {
      await updateFixedPairingCode(normalizedCurrent);
    }
  }

  /// 更新固定配对码内容（仅接受 4 位数字）。
  Future<void> updateFixedPairingCode(String code) async {
    final normalized = _normalizePairingCode(code);
    if (normalized == null) {
      return;
    }
    _fixedPairingCode = normalized;
    await _prefs.setString(_keyFixedPairingCode, normalized);
  }

  static String? _normalizePairingCode(String? value) {
    final code = value?.trim();
    if (code == null || !RegExp(r'^\d{4}$').hasMatch(code)) {
      return null;
    }
    return code;
  }

  void dispose() {
    oneTimeConnectionNotifier.dispose();
    autoSyncNotifier.dispose();
    fixedPairingCodeEnabledNotifier.dispose();
  }
}
