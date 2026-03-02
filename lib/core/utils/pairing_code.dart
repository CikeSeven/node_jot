import 'dart:math';

/// 配对码工具。
///
/// 生成 4 位数字码，供设备间一次性配对使用。
class PairingCode {
  /// 生成 0000~9999 的四位数字字符串。
  static String generate() {
    final random = Random.secure();
    final value = random.nextInt(10000);
    return value.toString().padLeft(4, '0');
  }
}
