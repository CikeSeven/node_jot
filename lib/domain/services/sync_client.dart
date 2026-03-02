import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';

import '../../core/utils/app_log.dart';

/// 同步客户端。
///
/// 封装 WebSocket 请求/响应与 register HTTP 调用。
class SyncClient {
  /// 发送一次 WebSocket 消息并等待单次响应。
  Future<Map<String, dynamic>> send({
    required String host,
    required int port,
    required Map<String, dynamic> message,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    AppLog.i('sync-client', 'send ${message['type']} to $host:$port');
    final channel = IOWebSocketChannel.connect(
      Uri.parse('ws://$host:$port/ws'),
      connectTimeout: timeout,
    );

    channel.sink.add(jsonEncode(message));
    final responseRaw = await channel.stream.first.timeout(timeout) as String;
    await channel.sink.close();

    final decoded = jsonDecode(responseRaw) as Map;
    AppLog.i('sync-client', 'received ${decoded['type']} from $host:$port');
    return decoded.cast<String, dynamic>();
  }

  /// 调用对端 register 接口，优先尝试 LocalSend 兼容路径。
  Future<Map<String, dynamic>> register({
    required String host,
    required int port,
    required Map<String, dynamic> payload,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    AppLog.i('sync-client', 'post register to $host:$port');
    try {
      return await _registerAtPath(
        host: host,
        port: port,
        path: '/api/localsend/v2/register',
        payload: payload,
        timeout: timeout,
      );
    } catch (_) {
      return _registerAtPath(
        host: host,
        port: port,
        path: '/register',
        payload: payload,
        timeout: timeout,
      );
    }
  }

  /// 按路径执行 HTTP register 请求。
  Future<Map<String, dynamic>> _registerAtPath({
    required String host,
    required int port,
    required String path,
    required Map<String, dynamic> payload,
    required Duration timeout,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.post(host, port, path).timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(payload)));

      final response = await request.close().timeout(timeout);
      final responseBody = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(responseBody) as Map;
      AppLog.i(
        'sync-client',
        'register response ${decoded['status']} from $host:$port via $path',
      );
      return decoded.cast<String, dynamic>();
    } finally {
      client.close(force: true);
    }
  }
}
