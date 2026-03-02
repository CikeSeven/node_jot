import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 单设备自动同步配置。
class DeviceAutoSyncSetting {
  const DeviceAutoSyncSetting({
    required this.enabled,
    required this.updatedAt,
  });

  final bool enabled;
  final DateTime updatedAt;
}

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
  static const _keyDeviceAutoSyncPrefix = 'app.settings.device_auto_sync.';
  static const _keyDeviceAutoSyncUpdatedAtPrefix =
      'app.settings.device_auto_sync.updated_at.';

  final SharedPreferences _prefs;
  final ValueNotifier<bool> oneTimeConnectionNotifier;
  final ValueNotifier<bool> autoSyncNotifier;
  final ValueNotifier<bool> fixedPairingCodeEnabledNotifier;
  String? _fixedPairingCode;
  final Map<String, ValueNotifier<bool>> _deviceAutoSyncNotifiers = {};

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

  /// 读取指定设备的自动同步开关。
  ///
  /// 若该设备尚未单独配置，则回退到全局默认自动同步设置。
  bool getDeviceAutoSyncEnabled(String deviceId) {
    return getDeviceAutoSyncSetting(deviceId).enabled;
  }

  /// 读取指定设备的自动同步配置（含最后修改时间）。
  ///
  /// 旧版本未记录更新时间的设备配置将回退到 Unix epoch（UTC）。
  DeviceAutoSyncSetting getDeviceAutoSyncSetting(String deviceId) {
    final enabled = _prefs.getBool(_deviceAutoSyncKey(deviceId));
    final updatedAtMs = _prefs.getInt(_deviceAutoSyncUpdatedAtKey(deviceId));
    final updatedAt =
        updatedAtMs == null
            ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
            : DateTime.fromMillisecondsSinceEpoch(updatedAtMs, isUtc: true);
    return DeviceAutoSyncSetting(
      enabled: enabled ?? autoSyncNotifier.value,
      updatedAt: updatedAt,
    );
  }

  /// 获取指定设备自动同步开关的监听器。
  ///
  /// 首次读取时会从持久化加载，未配置则使用全局默认值初始化内存态。
  ValueListenable<bool> deviceAutoSyncEnabledListenable(String deviceId) {
    final existing = _deviceAutoSyncNotifiers[deviceId];
    if (existing != null) {
      return existing;
    }
    final value = getDeviceAutoSyncEnabled(deviceId);
    final notifier = ValueNotifier<bool>(value);
    _deviceAutoSyncNotifiers[deviceId] = notifier;
    return notifier;
  }

  /// 为设备初始化自动同步开关（仅当该设备尚无配置时写入）。
  Future<void> ensureDeviceAutoSyncEnabled(
    String deviceId, {
    bool? defaultEnabled,
  }) async {
    final key = _deviceAutoSyncKey(deviceId);
    final updatedKey = _deviceAutoSyncUpdatedAtKey(deviceId);
    if (_prefs.containsKey(key)) {
      final persisted = _prefs.getBool(key) ?? autoSyncNotifier.value;
      _upsertDeviceAutoSyncNotifier(deviceId, persisted);
      if (!_prefs.containsKey(updatedKey)) {
        await _prefs.setInt(
          updatedKey,
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
              .millisecondsSinceEpoch,
        );
      }
      return;
    }

    final value = defaultEnabled ?? autoSyncNotifier.value;
    final now = DateTime.now().toUtc();
    await _prefs.setBool(key, value);
    await _prefs.setInt(updatedKey, now.millisecondsSinceEpoch);
    _upsertDeviceAutoSyncNotifier(deviceId, value);
  }

  /// 更新指定设备自动同步开关。
  ///
  /// 若传入更新时间早于本地记录，则忽略该更新（latest-wins）。
  Future<void> setDeviceAutoSyncEnabled(
    String deviceId,
    bool enabled, {
    DateTime? updatedAt,
  }) async {
    final incomingAt = (updatedAt ?? DateTime.now().toUtc()).toUtc();
    final current = getDeviceAutoSyncSetting(deviceId);
    if (current.updatedAt.isAfter(incomingAt)) {
      return;
    }

    await _prefs.setBool(_deviceAutoSyncKey(deviceId), enabled);
    await _prefs.setInt(
      _deviceAutoSyncUpdatedAtKey(deviceId),
      incomingAt.millisecondsSinceEpoch,
    );
    _upsertDeviceAutoSyncNotifier(deviceId, enabled);
  }

  /// 删除指定设备自动同步配置（设备解除配对时调用）。
  Future<void> removeDeviceAutoSyncEnabled(String deviceId) async {
    await _prefs.remove(_deviceAutoSyncKey(deviceId));
    await _prefs.remove(_deviceAutoSyncUpdatedAtKey(deviceId));
    _deviceAutoSyncNotifiers.remove(deviceId)?.dispose();
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

  String _deviceAutoSyncKey(String deviceId) {
    return '$_keyDeviceAutoSyncPrefix$deviceId';
  }

  String _deviceAutoSyncUpdatedAtKey(String deviceId) {
    return '$_keyDeviceAutoSyncUpdatedAtPrefix$deviceId';
  }

  void _upsertDeviceAutoSyncNotifier(String deviceId, bool value) {
    final existing = _deviceAutoSyncNotifiers[deviceId];
    if (existing != null) {
      if (existing.value != value) {
        existing.value = value;
      }
      return;
    }
    _deviceAutoSyncNotifiers[deviceId] = ValueNotifier<bool>(value);
  }

  void dispose() {
    oneTimeConnectionNotifier.dispose();
    autoSyncNotifier.dispose();
    fixedPairingCodeEnabledNotifier.dispose();
    for (final notifier in _deviceAutoSyncNotifiers.values) {
      notifier.dispose();
    }
    _deviceAutoSyncNotifiers.clear();
  }
}
