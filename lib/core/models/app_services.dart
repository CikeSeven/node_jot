import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/isar/isar_service.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/op_log_repository.dart';
import '../../data/repositories/sync_cursor_repository.dart';
import '../services/app_settings_service.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';
import '../../domain/services/crypto_service.dart';
import '../../domain/services/discovery_service.dart';
import '../../domain/services/local_device_service.dart';
import '../../domain/services/sync_client.dart';
import '../../domain/services/sync_engine.dart';
import '../../domain/services/sync_server.dart';

/// 全局服务容器 Provider。
///
/// 在 [main] 中通过 `overrideWithValue` 注入，业务层统一从这里读取依赖。
final appServicesProvider = Provider<AppServices>((ref) {
  throw UnimplementedError('appServicesProvider is overridden in main().');
});

/// NodeJot 运行期服务聚合。
///
/// 包含本地存储、同步、发现、加密、本地化等跨页面共享服务。
class AppServices {
  AppServices._({
    required this.isarService,
    required this.localeService,
    required this.themeService,
    required this.appSettingsService,
    required this.localDeviceService,
    required this.noteRepository,
    required this.deviceRepository,
    required this.opLogRepository,
    required this.syncCursorRepository,
    required this.cryptoService,
    required this.discoveryService,
    required this.syncServer,
    required this.syncClient,
    required this.syncEngine,
  });

  final IsarService isarService;
  final LocaleService localeService;
  final ThemeService themeService;
  final AppSettingsService appSettingsService;
  final LocalDeviceService localDeviceService;
  final NoteRepository noteRepository;
  final DeviceRepository deviceRepository;
  final OpLogRepository opLogRepository;
  final SyncCursorRepository syncCursorRepository;
  final CryptoService cryptoService;
  final DiscoveryService discoveryService;
  final SyncServer syncServer;
  final SyncClient syncClient;
  final SyncEngine syncEngine;

  /// 按依赖顺序创建所有服务并启动同步引擎。
  static Future<AppServices> create() async {
    final localeService = await LocaleService.create();
    final themeService = await ThemeService.create();
    final appSettingsService = await AppSettingsService.create();
    final localDeviceService = await LocalDeviceService.create();
    final isarService = await IsarService.open();

    final noteRepository = NoteRepository(isarService.db);
    final deviceRepository = DeviceRepository(isarService.db);
    final opLogRepository = OpLogRepository(isarService.db);
    final syncCursorRepository = SyncCursorRepository(isarService.db);
    final cryptoService = CryptoService();
    if (appSettingsService.oneTimeConnectionNotifier.value) {
      await deviceRepository.clearTrustedDevices();
    }

    final discoveryService = DiscoveryService(
      localDeviceService: localDeviceService,
    );
    final syncServer = SyncServer();
    final syncClient = SyncClient();

    final syncEngine = SyncEngine(
      localDeviceService: localDeviceService,
      noteRepository: noteRepository,
      deviceRepository: deviceRepository,
      opLogRepository: opLogRepository,
      syncCursorRepository: syncCursorRepository,
      cryptoService: cryptoService,
      discoveryService: discoveryService,
      syncServer: syncServer,
      syncClient: syncClient,
    );

    await syncEngine.start();

    return AppServices._(
      isarService: isarService,
      localeService: localeService,
      themeService: themeService,
      localDeviceService: localDeviceService,
      noteRepository: noteRepository,
      deviceRepository: deviceRepository,
      opLogRepository: opLogRepository,
      syncCursorRepository: syncCursorRepository,
      cryptoService: cryptoService,
      appSettingsService: appSettingsService,
      discoveryService: discoveryService,
      syncServer: syncServer,
      syncClient: syncClient,
      syncEngine: syncEngine,
    );
  }

  /// 释放资源。
  ///
  /// 关闭顺序与启动相反，避免出现已释放资源仍被后台任务访问的情况。
  Future<void> dispose() async {
    if (appSettingsService.oneTimeConnectionNotifier.value) {
      await deviceRepository.clearTrustedDevices();
    }
    await syncEngine.dispose();
    localeService.dispose();
    themeService.dispose();
    appSettingsService.dispose();
    await isarService.dispose();
  }
}
