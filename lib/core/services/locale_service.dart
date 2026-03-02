import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用语言服务。
///
/// 负责：
/// 1. 首次启动按系统语言初始化；
/// 2. 非支持语言自动回退英文；
/// 3. 提供运行时可监听的语言状态。
class LocaleService {
  LocaleService._({required SharedPreferences prefs, required Locale locale})
    : _prefs = prefs,
      localeNotifier = ValueNotifier<Locale>(locale);

  static const _keyLocaleCode = 'app.locale.code';

  final SharedPreferences _prefs;
  final ValueNotifier<Locale> localeNotifier;

  /// 创建语言服务并完成初始化语言判定。
  static Future<LocaleService> create() async {
    final prefs = await SharedPreferences.getInstance();
    var code = prefs.getString(_keyLocaleCode);

    if (code == null || !_isSupported(code)) {
      final systemCode =
          PlatformDispatcher.instance.locale.languageCode.toLowerCase();
      code = _normalizeLanguageCode(systemCode);
      await prefs.setString(_keyLocaleCode, code);
    }

    return LocaleService._(prefs: prefs, locale: Locale(code));
  }

  /// 设置并持久化当前语言。
  Future<void> setLocale(Locale locale) async {
    final code = _normalizeLanguageCode(locale.languageCode);
    localeNotifier.value = Locale(code);
    await _prefs.setString(_keyLocaleCode, code);
  }

  void dispose() {
    localeNotifier.dispose();
  }

  /// 规范化语言码，保证仅输出受支持值。
  static String _normalizeLanguageCode(String code) {
    final lower = code.toLowerCase();
    if (lower.startsWith('zh')) {
      return 'zh';
    }
    if (lower == 'en') {
      return 'en';
    }
    return 'en';
  }

  /// 检查语言码是否受支持。
  static bool _isSupported(String code) {
    return code == 'en' || code == 'zh';
  }
}
