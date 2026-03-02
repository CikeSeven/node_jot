import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// NodeJot 日志门面。
///
/// 统一日志格式，便于过滤与定位问题：
/// `[NodeJot][tag] message`
class AppLog {
  /// 输出普通信息日志。
  static void i(String tag, String message) {
    _emit(tag, message);
  }

  /// 输出告警日志。
  static void w(String tag, String message) {
    _emit(tag, 'WARN: $message');
  }

  /// 输出错误日志，可附带异常对象与堆栈。
  static void e(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _emit(tag, 'ERROR: $message');
    if (error != null) {
      _emit(tag, 'ERROR_DETAIL: $error');
    }
    if (stackTrace != null) {
      developer.log(
        message,
        name: 'NodeJot.$tag',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 实际日志写出逻辑。
  ///
  /// Debug 模式下同时走 `debugPrint`，并始终写入 `developer.log`。
  static void _emit(String tag, String message) {
    final line = '[NodeJot][$tag] $message';
    if (kDebugMode) {
      debugPrint(line);
    }
    developer.log(message, name: 'NodeJot.$tag');
  }
}
