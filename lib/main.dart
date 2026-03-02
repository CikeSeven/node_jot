import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/node_jot_app.dart';
import 'core/models/app_services.dart';
import 'core/utils/local_network_lock.dart';

/// NodeJot 应用入口。
///
/// 启动顺序：
/// 1. 初始化 Flutter 绑定。
/// 2. 在 Android 上申请组播锁，保证局域网发现稳定。
/// 3. 创建并注入全局服务容器。
/// 4. 启动根组件。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNetworkLock.acquireIfNeeded();
  final services = await AppServices.create();
  runApp(
    ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(services)],
      child: const NodeJotApp(),
    ),
  );
}
