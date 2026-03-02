import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/constants/app_constants.dart';
import '../../core/utils/app_log.dart';
import '../models/discovered_device.dart';
import 'local_device_service.dart';

/// 局域网设备发现服务。
///
/// 通过 UDP 广播 + 组播维护在线设备列表。
class DiscoveryService {
  DiscoveryService({required LocalDeviceService localDeviceService})
    : _localDeviceService = localDeviceService;

  final LocalDeviceService _localDeviceService;

  final StreamController<List<DiscoveredDevice>> _devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();

  final Map<String, DiscoveredDevice> _devices = {};
  final Set<InternetAddress> _broadcastTargets = <InternetAddress>{};
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _probeTimer;
  Timer? _cleanupTimer;
  bool _started = false;

  /// 已发现设备流（实时更新）。
  ///
  /// 每次有新订阅时先回放当前缓存列表，避免页面晚订阅时只能等待下一次广播。
  Stream<List<DiscoveredDevice>> get devicesStream async* {
    yield _sortedDevices();
    yield* _devicesController.stream;
  }

  /// 外部直接写入发现结果（例如 register-back 成功后的回填）。
  void upsertDevice({
    required String deviceId,
    required String displayName,
    required String host,
    required int port,
    required String publicKey,
  }) {
    if (deviceId == _localDeviceService.profile.deviceId) {
      return;
    }
    _devices[deviceId] = DiscoveredDevice(
      deviceId: deviceId,
      displayName: displayName,
      host: host,
      port: port,
      publicKey: publicKey,
      lastSeen: DateTime.now().toUtc(),
    );
    _emitDevices();
  }

  /// 启动 UDP 监听与周期广播任务。
  Future<void> start() async {
    if (_started) {
      return;
    }

    _socket ??= await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      AppConstants.discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );

    _socket!
      ..broadcastEnabled = true
      ..multicastLoopback = true
      ..readEventsEnabled = true
      ..listen(_onSocketEvent);

    try {
      _socket!.joinMulticast(
        InternetAddress(AppConstants.discoveryMulticastAddress),
      );
    } catch (e, st) {
      AppLog.w('discovery', 'join multicast failed: $e');
      AppLog.e('discovery', 'join multicast stack', error: e, stackTrace: st);
    }
    await _rebuildBroadcastTargets();

    _broadcastTimer ??= Timer.periodic(
      AppConstants.discoveryBroadcastInterval,
      (_) => _broadcastPresence(),
    );
    _probeTimer ??= Timer.periodic(
      AppConstants.discoveryProbeInterval,
      (_) => _sendProbe(),
    );
    _cleanupTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => _cleanupExpiredDevices(),
    );

    _started = true;
    AppLog.i(
      'discovery',
      'started on ${_socket!.address.address}:${_socket!.port}',
    );
    await refreshNow();
  }

  /// 手动刷新：重建目标地址、发送探测与公告。
  Future<void> refreshNow() async {
    await _rebuildBroadcastTargets();
    _cleanupExpiredDevices();
    _sendProbe();
    _broadcastPresence();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _sendProbe();
    _broadcastPresence();
  }

  /// UDP Socket 事件处理入口。
  void _onSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _socket == null) {
      return;
    }

    while (true) {
      final datagram = _socket!.receive();
      if (datagram == null) {
        break;
      }

      try {
        final payload = jsonDecode(utf8.decode(datagram.data)) as Map;
        _handlePacket(payload.cast<String, dynamic>(), datagram.address);
      } catch (e) {
        AppLog.w(
          'discovery',
          'invalid datagram from ${datagram.address.address}: $e',
        );
      }
    }
  }

  /// 解析并分发收到的发现报文。
  void _handlePacket(Map<String, dynamic> payload, InternetAddress source) {
    final type = payload['type'] as String?;
    if (type == null) {
      return;
    }

    switch (type) {
      case 'probe':
        if (_isSelfPacket(payload)) {
          return;
        }
        AppLog.i('discovery', 'received probe from ${source.address}');
        _sendProbeResponse(source);
        _broadcastPresence();
        return;
      case 'announce':
      case 'probe_response':
        _registerDiscoveredDevice(payload, source);
        return;
      default:
        return;
    }
  }

  bool _isSelfPacket(Map<String, dynamic> payload) {
    return payload['deviceId'] == _localDeviceService.profile.deviceId;
  }

  /// 注册/更新远端设备到内存列表。
  void _registerDiscoveredDevice(
    Map<String, dynamic> payload,
    InternetAddress source,
  ) {
    final deviceId = payload['deviceId'] as String?;
    if (deviceId == null || deviceId == _localDeviceService.profile.deviceId) {
      return;
    }

    final displayName = payload['displayName'] as String? ?? 'NodeJot Device';
    final port = _readInt(payload['syncPort']) ?? AppConstants.syncPort;
    final publicKey = payload['publicKey'] as String? ?? '';

    final previous = _devices[deviceId];
    _devices[deviceId] = DiscoveredDevice(
      deviceId: deviceId,
      displayName: displayName,
      host: source.address,
      port: port,
      publicKey: publicKey,
      lastSeen: DateTime.now().toUtc(),
    );

    final isNew = previous == null;
    if (isNew) {
      AppLog.i(
        'discovery',
        'discovered device $displayName ($deviceId) at ${source.address}:$port',
      );
    }
    _emitDevices();
  }

  /// 容错读取数字字段（兼容 int/string/double）。
  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is double) {
      return value.toInt();
    }
    return null;
  }

  void _broadcastPresence() {
    _sendPresencePacket('announce');
  }

  void _sendProbe() {
    _sendPresencePacket('probe');
  }

  void _sendProbeResponse(InternetAddress target) {
    _sendPresencePacket('probe_response', target: target);
  }

  /// 发送标准发现载荷。
  void _sendPresencePacket(String type, {InternetAddress? target}) {
    if (_socket == null) {
      return;
    }

    final profile = _localDeviceService.profile;
    final payload = {
      'type': type,
      'deviceId': profile.deviceId,
      'displayName': profile.displayName,
      'syncPort': AppConstants.syncPort,
      'publicKey': profile.publicKey,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    _sendPacket(payload, target: target);
  }

  /// 向指定目标或所有广播目标发送 UDP 数据包。
  void _sendPacket(Map<String, dynamic> payload, {InternetAddress? target}) {
    if (_socket == null) {
      return;
    }
    final bytes = utf8.encode(jsonEncode(payload));
    if (target != null) {
      _socket!.send(bytes, target, AppConstants.discoveryPort);
      return;
    }

    if (_broadcastTargets.isEmpty) {
      _broadcastTargets.add(InternetAddress('255.255.255.255'));
      _broadcastTargets.add(
        InternetAddress(AppConstants.discoveryMulticastAddress),
      );
    }

    for (final address in _broadcastTargets) {
      final sent = _socket!.send(bytes, address, AppConstants.discoveryPort);
      if (sent <= 0) {
        AppLog.w(
          'discovery',
          'send failed to ${address.address}:${AppConstants.discoveryPort}',
        );
      }
    }
  }

  /// 重建广播目标集合（全局广播 + 组播 + 各网卡定向广播）。
  Future<void> _rebuildBroadcastTargets() async {
    _broadcastTargets
      ..clear()
      ..add(InternetAddress('255.255.255.255'))
      ..add(InternetAddress(AppConstants.discoveryMulticastAddress));

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final directed = _toDirectedBroadcast(address);
          if (directed != null) {
            _broadcastTargets.add(directed);
          }
        }
      }
      AppLog.i(
        'discovery',
        'broadcast targets: ${_broadcastTargets.map((e) => e.address).join(', ')}',
      );
    } catch (e, st) {
      AppLog.e(
        'discovery',
        'failed to enumerate interfaces',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// 基于本机 IPv4 地址推导定向广播地址（x.x.x.255）。
  InternetAddress? _toDirectedBroadcast(InternetAddress address) {
    if (address.type != InternetAddressType.IPv4) {
      return null;
    }
    final parts = address.address.split('.');
    if (parts.length != 4) {
      return null;
    }
    final last = int.tryParse(parts[3]);
    if (last == null) {
      return null;
    }
    if (parts[0] == '169' && parts[1] == '254') {
      return null;
    }
    return InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255');
  }

  /// 清理超时设备（默认超过 12 秒未刷新即过期）。
  void _cleanupExpiredDevices() {
    final now = DateTime.now().toUtc();
    final keysToRemove = <String>[];

    for (final entry in _devices.entries) {
      if (now.difference(entry.value.lastSeen) > const Duration(seconds: 12)) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _devices.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      _emitDevices();
    }
  }

  /// 输出排序后的设备列表。
  void _emitDevices() {
    _devicesController.add(_sortedDevices());
  }

  List<DiscoveredDevice> _sortedDevices() {
    return _devices.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  /// 停止发现服务并释放资源。
  Future<void> dispose() async {
    _broadcastTimer?.cancel();
    _probeTimer?.cancel();
    _cleanupTimer?.cancel();
    _started = false;
    _socket?.close();
    await _devicesController.close();
  }
}
