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
  }) : _prefs = prefs,
       oneTimeConnectionNotifier = ValueNotifier<bool>(oneTimeConnection),
       autoSyncNotifier = ValueNotifier<bool>(autoSync);

  static const _keyOneTimeConnection = 'app.settings.one_time_connection';
  static const _keyAutoSync = 'app.settings.auto_sync';

  final SharedPreferences _prefs;
  final ValueNotifier<bool> oneTimeConnectionNotifier;
  final ValueNotifier<bool> autoSyncNotifier;

  static Future<AppSettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final oneTime = prefs.getBool(_keyOneTimeConnection) ?? false;
    final autoSync = prefs.getBool(_keyAutoSync) ?? false;
    return AppSettingsService._(
      prefs: prefs,
      oneTimeConnection: oneTime,
      autoSync: autoSync,
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

  void dispose() {
    oneTimeConnectionNotifier.dispose();
    autoSyncNotifier.dispose();
  }
}

