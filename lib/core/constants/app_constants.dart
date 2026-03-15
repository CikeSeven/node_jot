/// 应用级常量配置。
///
/// 网络端口与发现参数需在多端保持一致，否则设备将无法互通。
class AppConstants {
  /// 产品名称。
  static const String appName = 'NodeJot';

  /// WebSocket/HTTP 同步服务端口。
  static const int syncPort = 45888;

  /// UDP 发现端口。
  static const int discoveryPort = 45890;

  /// 发现使用的 IPv4 组播地址。
  static const String discoveryMulticastAddress = '239.255.42.99';

  /// 设备公告广播周期。
  static const Duration discoveryBroadcastInterval = Duration(seconds: 3);

  /// 主动探测周期。
  static const Duration discoveryProbeInterval = Duration(seconds: 4);
}
 