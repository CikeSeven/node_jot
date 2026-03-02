import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/utils/app_log.dart';

typedef ServerMessageHandler =
    Future<Map<String, dynamic>> Function(
      Map<String, dynamic> message,
      InternetAddress remoteAddress,
    );
typedef RegisterHandler =
    Future<Map<String, dynamic>> Function(
      Map<String, dynamic> payload,
      InternetAddress remoteAddress,
    );

/// 同步服务端。
///
/// 提供两个入口：
/// - `POST /register`（含 LocalSend 兼容路径）用于设备反向登记；
/// - `GET /ws` 升级 WebSocket 用于配对与同步消息交换。
class SyncServer {
  HttpServer? _server;

  /// 启动服务并绑定消息处理器。
  Future<void> start({
    required int port,
    required ServerMessageHandler onMessage,
    required RegisterHandler onRegister,
  }) async {
    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    AppLog.i('sync-server', 'listening at ${_server!.address.address}:$port');

    unawaited(
      _server!.forEach((request) async {
        if ((request.uri.path == '/register' ||
                request.uri.path == '/api/localsend/v2/register') &&
            request.method.toUpperCase() == 'POST') {
          try {
            final body = await utf8.decoder.bind(request).join();
            final data = jsonDecode(body) as Map;
            final remote =
                request.connectionInfo?.remoteAddress ??
                InternetAddress.anyIPv4;
            final response = await onRegister(
              data.cast<String, dynamic>(),
              remote,
            );
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(response))
              ..close();
            return;
          } catch (e) {
            AppLog.w('sync-server', 'register failed: $e');
            request.response
              ..statusCode = HttpStatus.badRequest
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'status': 'error', 'message': e.toString()}))
              ..close();
            return;
          }
        }

        if (request.uri.path != '/ws') {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
          return;
        }

        final socket = await WebSocketTransformer.upgrade(request);
        AppLog.i(
          'sync-server',
          'websocket connected from ${request.connectionInfo?.remoteAddress.address}',
        );
        socket.listen(
          (raw) async {
            try {
              final message = jsonDecode(raw as String) as Map;
              final remote =
                  request.connectionInfo?.remoteAddress ??
                  InternetAddress.anyIPv4;
              final response = await onMessage(
                message.cast<String, dynamic>(),
                remote,
              );
              socket.add(jsonEncode(response));
            } catch (e) {
              AppLog.w('sync-server', 'handle message failed: $e');
              socket.add(
                jsonEncode({'type': 'error', 'message': e.toString()}),
              );
            }
          },
          onDone: () async => socket.close(),
          onError: (_) => socket.close(),
        );
      }),
    );
  }

  /// 关闭服务端。
  Future<void> stop() async {
    await _server?.close(force: true);
    AppLog.i('sync-server', 'stopped');
    _server = null;
  }
}
