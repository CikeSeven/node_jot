import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用主题模式服务。
///
/// 支持三种模式并持久化：
/// - 跟随系统
/// - 浅色
/// - 深色
class ThemeService {
  ThemeService._({required SharedPreferences prefs, required ThemeMode mode})
    : _prefs = prefs,
      themeModeNotifier = ValueNotifier<ThemeMode>(mode);

  static const _keyThemeMode = 'app.theme.mode';

  final SharedPreferences _prefs;
  final ValueNotifier<ThemeMode> themeModeNotifier;

  static Future<ThemeService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyThemeMode);
    final mode = _parseMode(raw);
    return ThemeService._(prefs: prefs, mode: mode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    await _prefs.setString(_keyThemeMode, mode.name);
  }

  void dispose() {
    themeModeNotifier.dispose();
  }

  static ThemeMode _parseMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}

