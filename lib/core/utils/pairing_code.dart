import 'dart:math';

/// 配对码工具。
///
/// 生成 6 位数字码，供设备间一次性配对使用。
class PairingCode {
  /// 生成 000000~999999 的六位数字字符串。
  static String generate() {
    final random = Random.secure();
    final value = random.nextInt(1000000);
    return value.toString().padLeft(6, '0');
  }
}
