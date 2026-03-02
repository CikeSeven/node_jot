import 'dart:io';

import 'package:flutter/services.dart';

import 'app_log.dart';

/// Android 本地网络能力增强工具。
///
/// 在部分设备上，未持有 MulticastLock 时 UDP 组播/广播会被系统限流或丢弃。
class LocalNetworkLock {
  static const MethodChannel _channel = MethodChannel('node_jot/network');

  /// Android 平台申请组播锁，其它平台直接忽略。
  static Future<void> acquireIfNeeded() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<bool>('acquireMulticastLock');
      AppLog.i('network-lock', 'android multicast lock acquired');
    } catch (e, st) {
      AppLog.e(
        'network-lock',
        'failed to acquire multicast lock',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Android 平台释放组播锁，其它平台直接忽略。
  static Future<void> releaseIfNeeded() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<bool>('releaseMulticastLock');
      AppLog.i('network-lock', 'android multicast lock released');
    } catch (e, st) {
      AppLog.e(
        'network-lock',
        'failed to release multicast lock',
        error: e,
        stackTrace: st,
      );
    }
  }
}
