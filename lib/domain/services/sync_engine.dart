import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/id.dart';
import '../../core/utils/pairing_code.dart';
import '../../data/isar/collections/device_entity.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/op_log_repository.dart';
import '../../data/repositories/sync_cursor_repository.dart';
import '../models/discovered_device.dart';
import '../models/sync_operation.dart';
import 'crypto_service.dart';
import 'discovery_service.dart';
import 'local_device_service.dart';
import 'sync_client.dart';
import 'sync_server.dart';

/// 已配对设备运行期连接状态。
enum TrustedDeviceConnectionState { unknown, connecting, connected, invalid }

/// 本地保存触发来源。
enum SaveTriggerSource {
  /// 用户编辑器输入触发的本地保存（允许自动同步）。
  localUser,

  /// 远端同步应用触发的内部保存（不触发自动同步）。
  remoteApply,

  /// 内部冲突合并/修复触发的保存（不触发自动同步）。
  internalMerge,
}

/// NodeJot 同步编排核心。
///
/// 职责：
/// - 管理发现、配对、同步生命周期；
/// - 处理服务端入站消息；
/// - 维护本地 Lamport 操作日志与对端游标。
class SyncEngine {
  SyncEngine({
    required LocalDeviceService localDeviceService,
    required NoteRepository noteRepository,
    required DeviceRepository deviceRepository,
    required OpLogRepository opLogRepository,
    required SyncCursorRepository syncCursorRepository,
    required AppSettingsService appSettingsService,
    required CryptoService cryptoService,
    required DiscoveryService discoveryService,
    required SyncServer syncServer,
    required SyncClient syncClient,
  }) : _localDeviceService = localDeviceService,
       _noteRepository = noteRepository,
       _deviceRepository = deviceRepository,
       _opLogRepository = opLogRepository,
       _syncCursorRepository = syncCursorRepository,
       _appSettingsService = appSettingsService,
       _cryptoService = cryptoService,
       _discoveryService = discoveryService,
       _syncServer = syncServer,
       _syncClient = syncClient,
       pairingCode = ValueNotifier<String>(
         _resolveInitialPairingCode(
           fixedPairingCodeEnabled:
               appSettingsService.fixedPairingCodeEnabledNotifier.value,
           fixedPairingCode: appSettingsService.fixedPairingCode,
         ),
       );

  final LocalDeviceService _localDeviceService;
  final NoteRepository _noteRepository;
  final DeviceRepository _deviceRepository;
  final OpLogRepository _opLogRepository;
  final SyncCursorRepository _syncCursorRepository;
  final AppSettingsService _appSettingsService;
  final CryptoService _cryptoService;
  final DiscoveryService _discoveryService;
  final SyncServer _syncServer;
  final SyncClient _syncClient;

  /// 当前显示给用户的 4 位配对码。
  final ValueNotifier<String> pairingCode;
  final ValueNotifier<Map<String, TrustedDeviceConnectionState>>
  trustedConnectionStates =
      ValueNotifier<Map<String, TrustedDeviceConnectionState>>({});

  StreamSubscription<List<DiscoveredDevice>>? _discoverySub;
  StreamSubscription<List<DeviceEntity>>? _trustedSub;
  Timer? _autoSyncTimer;
  bool _autoSyncInFlight = false;
  bool _autoSyncPending = false;
  final Map<String, DateTime> _lastRegisterAttempts = {};
  final Map<String, DateTime> _lastTrustedProbeAttempts = {};
  final Map<String, DeviceEntity> _trustedById = {};
  final Map<String, DiscoveredDevice> _discoveredById = {};
  final Set<String> _probingTrustedDeviceIds = <String>{};
  final Set<String> _connectAutoSyncedDeviceIds = <String>{};
  static const Duration _autoSyncDebounce = Duration(milliseconds: 400);

  /// 启动发现服务、同步服务端并订阅发现结果。
  Future<void> start() async {
    await _syncPairingCodeWithSettingsOnStart();

    _trustedSub = _deviceRepository.watchTrustedDevices().listen((trustedList) {
      final previousIds = _trustedById.keys.toSet();
      final trustedIds = trustedList.map((e) => e.deviceId).toSet();
      _trustedById
        ..clear()
        ..addEntries(trustedList.map((e) => MapEntry(e.deviceId, e)));

      // 为已配对设备确保存在配对设置配置。
      for (final trusted in trustedList) {
        unawaited(
          _appSettingsService.ensureDeviceAutoSyncEnabled(trusted.deviceId),
        );
        unawaited(
          _appSettingsService.ensureDeviceOneTimeConnectionEnabled(
            trusted.deviceId,
          ),
        );
      }

      // 清理已删除设备的运行期状态。
      final next = Map<String, TrustedDeviceConnectionState>.from(
        trustedConnectionStates.value,
      )..removeWhere((deviceId, _) => !trustedIds.contains(deviceId));
      trustedConnectionStates.value = next;
      _connectAutoSyncedDeviceIds.removeWhere(
        (deviceId) => !trustedIds.contains(deviceId),
      );

      // 仅对新加入的配对设备触发一次即时检查，避免流更新时状态抖动。
      for (final trusted in trustedList) {
        if (previousIds.contains(trusted.deviceId)) {
          continue;
        }
        final discovered = _discoveredById[trusted.deviceId];
        if (discovered != null) {
          unawaited(_probeTrustedDevice(discovered, force: true));
        }
      }
    });

    await _discoveryService.start();
    await _syncServer.start(
      port: AppConstants.syncPort,
      onMessage: _onServerMessage,
      onRegister: _handleRegister,
    );
    AppLog.i(
      'sync-engine',
      'started as ${_localDeviceService.profile.displayName} (${_localDeviceService.profile.deviceId})',
    );

    _discoverySub = _discoveryService.devicesStream.listen((devices) {
      AppLog.i(
        'sync-engine',
        'discovery list updated: ${devices.length} device(s)',
      );
      _discoveredById
        ..clear()
        ..addEntries(devices.map((e) => MapEntry(e.deviceId, e)));

      for (final device in devices) {
        unawaited(_handleDiscoveredDevice(device));
        unawaited(_registerBackIfNeeded(device));
      }
    });
  }

  /// 释放同步相关资源。
  Future<void> dispose() async {
    _autoSyncTimer?.cancel();
    await _trustedSub?.cancel();
    await _discoverySub?.cancel();
    pairingCode.dispose();
    trustedConnectionStates.dispose();
    await _syncServer.stop();
    await _discoveryService.dispose();
  }

  /// 发现设备流。
  Stream<List<DiscoveredDevice>> get discoveredDevices =>
      _discoveryService.devicesStream;

  /// 已配对设备流。
  Stream<List<DeviceEntity>> get trustedDevices =>
      _deviceRepository.watchTrustedDevices();

  /// 刷新配对码。
  Future<void> refreshPairingCode() async {
    pairingCode.value = PairingCode.generate();
    if (_appSettingsService.fixedPairingCodeEnabledNotifier.value) {
      await _appSettingsService.updateFixedPairingCode(pairingCode.value);
    }
  }

  /// 手动刷新局域网发现。
  Future<void> refreshDiscovery() async {
    AppLog.i('sync-engine', 'manual discovery refresh');
    _lastRegisterAttempts.clear();
    _lastTrustedProbeAttempts.clear();
    await _discoveryService.refreshNow();
  }

  Future<void> _handleDiscoveredDevice(DiscoveredDevice device) async {
    await _deviceRepository.upsertSeenDevice(
      deviceId: device.deviceId,
      displayName: device.displayName,
      host: device.host,
      port: device.port,
      publicKey: device.publicKey,
    );

    if (_trustedById.containsKey(device.deviceId)) {
      await _probeTrustedDevice(device);
    }
  }

  TrustedDeviceConnectionState connectionStateOf(String deviceId) {
    return trustedConnectionStates.value[deviceId] ??
        TrustedDeviceConnectionState.unknown;
  }

  static String _resolveInitialPairingCode({
    required bool fixedPairingCodeEnabled,
    required String? fixedPairingCode,
  }) {
    if (fixedPairingCodeEnabled && _isValidPairingCode(fixedPairingCode)) {
      return fixedPairingCode!;
    }
    return PairingCode.generate();
  }

  static bool _isValidPairingCode(String? value) {
    return value != null && RegExp(r'^\d{4}$').hasMatch(value);
  }

  /// 启动时对齐配对码持久化状态。
  ///
  /// 若开启了固定配对码但本地还没有有效值，则将当前配对码写入持久化。
  Future<void> _syncPairingCodeWithSettingsOnStart() async {
    if (!_appSettingsService.fixedPairingCodeEnabledNotifier.value) {
      return;
    }

    final fixedCode = _appSettingsService.fixedPairingCode;
    if (_isValidPairingCode(fixedCode)) {
      if (pairingCode.value != fixedCode) {
        pairingCode.value = fixedCode!;
      }
      return;
    }

    await _appSettingsService.updateFixedPairingCode(pairingCode.value);
  }

  /// 更新本机显示名。
  Future<void> updateLocalDisplayName(String value) async {
    await _localDeviceService.updateDisplayName(value);
  }

  /// 保存本地笔记并写入本地操作日志。
  Future<SaveNoteOutcome> saveLocalNote({
    String? noteId,
    required String title,
    required String contentMd,
    int? expectedHeadRevision,
    SaveTriggerSource source = SaveTriggerSource.localUser,
  }) async {
    final profile = _localDeviceService.profile;
    final outcome = await _noteRepository.saveLocalNote(
      noteId: noteId,
      title: title,
      contentMd: contentMd,
      editorDeviceId: profile.deviceId,
      expectedHeadRevision: expectedHeadRevision,
    );

    final lamport = await _nextLamport();
    final opType = outcome.isNew ? 'create' : 'update';

    await _opLogRepository.appendOperation(
      SyncOperation(
        opId: newUuid(),
        lamport: lamport,
        deviceId: profile.deviceId,
        noteId: outcome.note.noteId,
        opType: opType,
        payload: _noteRepository.toSnapshot(outcome.note),
        createdAt: DateTime.now().toUtc(),
      ),
    );

    if (source == SaveTriggerSource.localUser) {
      _scheduleAutoSync();
    }

    return outcome;
  }

  /// 删除本地笔记并写入 delete 操作日志。
  Future<void> deleteLocalNote(String noteId) async {
    final profile = _localDeviceService.profile;
    await _noteRepository.softDeleteLocalNote(
      noteId: noteId,
      editorDeviceId: profile.deviceId,
    );

    final note = await _noteRepository.getByNoteId(noteId);
    if (note == null) {
      return;
    }

    final lamport = await _nextLamport();
    await _opLogRepository.appendOperation(
      SyncOperation(
        opId: newUuid(),
        lamport: lamport,
        deviceId: profile.deviceId,
        noteId: note.noteId,
        opType: 'delete',
        payload: _noteRepository.toSnapshot(note),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    _scheduleAutoSync();
  }

  /// 恢复本地软删除笔记并写入 update 操作日志。
  Future<void> restoreDeletedLocalNote(String noteId) async {
    final profile = _localDeviceService.profile;
    final restored = await _noteRepository.restoreSoftDeletedLocalNote(
      noteId: noteId,
      editorDeviceId: profile.deviceId,
    );
    if (restored == null) {
      return;
    }

    final lamport = await _nextLamport();
    await _opLogRepository.appendOperation(
      SyncOperation(
        opId: newUuid(),
        lamport: lamport,
        deviceId: profile.deviceId,
        noteId: restored.noteId,
        opType: 'update',
        payload: _noteRepository.toSnapshot(restored),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    _scheduleAutoSync();
  }

  /// 归档本地笔记并写入 update 操作日志。
  Future<void> archiveLocalNote(String noteId) async {
    await _setArchiveState(noteId: noteId, archived: true);
  }

  /// 取消归档本地笔记并写入 update 操作日志。
  Future<void> unarchiveLocalNote(String noteId) async {
    await _setArchiveState(noteId: noteId, archived: false);
  }

  Future<void> _setArchiveState({
    required String noteId,
    required bool archived,
  }) async {
    final profile = _localDeviceService.profile;
    final note = await _noteRepository.setArchivedStateLocal(
      noteId: noteId,
      editorDeviceId: profile.deviceId,
      archived: archived,
    );
    if (note == null) {
      return;
    }

    final lamport = await _nextLamport();
    await _opLogRepository.appendOperation(
      SyncOperation(
        opId: newUuid(),
        lamport: lamport,
        deviceId: profile.deviceId,
        noteId: note.noteId,
        opType: 'update',
        payload: _noteRepository.toSnapshot(note),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    _scheduleAutoSync();
  }

  /// 调度自动同步（防抖）。
  void _scheduleAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer(_autoSyncDebounce, () {
      unawaited(_runAutoSync());
    });
  }

  /// 执行自动同步：仅同步到“已连接 + 开启自动同步”的设备。
  Future<void> _runAutoSync() async {
    if (_autoSyncInFlight) {
      _autoSyncPending = true;
      return;
    }

    _autoSyncInFlight = true;
    try {
      do {
        _autoSyncPending = false;
        final targets =
            _trustedById.values.where((device) {
              final state = connectionStateOf(device.deviceId);
              if (state != TrustedDeviceConnectionState.connected) {
                return false;
              }
              return _appSettingsService.getDeviceAutoSyncEnabled(
                device.deviceId,
              );
            }).toList();

        for (final device in targets) {
          try {
            await syncWithTrustedDevice(device);
          } catch (e) {
            AppLog.w(
              'sync-engine',
              'auto sync failed for ${device.displayName} (${device.deviceId}): $e',
            );
          }
        }
      } while (_autoSyncPending);
    } finally {
      _autoSyncInFlight = false;
    }
  }

  /// 使用发现到的设备进行配对。
  Future<void> pairWithDevice({
    required DiscoveredDevice device,
    required String code,
  }) async {
    final profile = _localDeviceService.profile;
    AppLog.i(
      'sync-engine',
      'pair start -> ${device.displayName} (${device.host}:${device.port})',
    );

    final response = await _syncClient.send(
      host: device.host,
      port: device.port,
      message: {
        'type': 'pair_request',
        'deviceId': profile.deviceId,
        'displayName': profile.displayName,
        'publicKey': profile.publicKey,
        'code': code,
      },
    );

    if (response['type'] != 'pair_ok') {
      AppLog.w(
        'sync-engine',
        'pair failed response: ${response['type']} ${response['message']}',
      );
      throw Exception((response['message'] as String?) ?? 'Pair failed');
    }

    final remotePublicKey = response['publicKey'] as String;
    final sharedKey = await _cryptoService.deriveSharedKey(
      myPrivateKeyBase64: profile.privateKey,
      remotePublicKeyBase64: remotePublicKey,
      pairingCode: code,
    );

    await _deviceRepository.upsertTrustedDevice(
      deviceId: response['deviceId'] as String,
      displayName: response['displayName'] as String,
      host: device.host,
      port: device.port,
      publicKey: remotePublicKey,
      sharedKey: sharedKey,
    );
    await _appSettingsService.ensureDeviceAutoSyncEnabled(
      response['deviceId'] as String,
    );
    await _appSettingsService.ensureDeviceOneTimeConnectionEnabled(
      response['deviceId'] as String,
    );
    AppLog.i('sync-engine', 'pair success with ${device.displayName}');
  }

  /// 通过手动输入 host/port 直接配对。
  Future<void> pairWithHost({
    required String host,
    required int port,
    required String code,
  }) async {
    final pseudoDevice = DiscoveredDevice(
      deviceId: 'manual-$host:$port',
      displayName: '$host:$port',
      host: host,
      port: port,
      publicKey: '',
      lastSeen: DateTime.now().toUtc(),
    );
    await pairWithDevice(device: pseudoDevice, code: code);
  }

  /// 与指定设备执行一次双向增量同步（pull + push）。
  Future<void> syncWithDevice(DiscoveredDevice device) async {
    final trusted = await _deviceRepository.getByDeviceId(device.deviceId);
    if (trusted == null || !trusted.trusted || trusted.sharedKey == null) {
      AppLog.w(
        'sync-engine',
        'sync blocked: device not paired ${device.displayName}',
      );
      throw Exception('Device not paired yet.');
    }
    AppLog.i(
      'sync-engine',
      'sync start -> ${device.displayName} (${device.host}:${device.port})',
    );

    final localProfile = _localDeviceService.profile;
    final lastSeen = await _syncCursorRepository.getLastLamportSeen(
      device.deviceId,
    );

    final secureRequest = await _cryptoService.encryptEnvelope(
      senderDeviceId: localProfile.deviceId,
      keyBase64: trusted.sharedKey!,
      payload: {
        'type': 'sync_request',
        'requesterDeviceId': localProfile.deviceId,
        'lastLamportSeen': lastSeen,
      },
    );

    final responseEnvelope = await _syncClient.send(
      host: device.host,
      port: device.port,
      message: secureRequest,
    );

    final response = await _decryptIfSecure(
      responseEnvelope,
      trusted.sharedKey!,
    );
    if (response['type'] != 'sync_response') {
      AppLog.w('sync-engine', 'sync request rejected: ${response['message']}');
      throw Exception(
        (response['message'] as String?) ?? 'Sync request failed',
      );
    }

    final remoteOps =
        (response['ops'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .map(SyncOperation.fromMap)
            .toList();

    var maxRemoteLamport = lastSeen;
    for (final op in remoteOps) {
      await _applyRemoteOperation(op);
      if (op.lamport > maxRemoteLamport) {
        maxRemoteLamport = op.lamport;
      }
    }
    AppLog.i('sync-engine', 'pulled ${remoteOps.length} op(s) from remote');

    await _syncCursorRepository.saveCursor(device.deviceId, maxRemoteLamport);

    final serverSeenLamport =
        response['serverSeenRequesterLamport'] as int? ?? 0;
    final localOps = await _opLogRepository.getOpsAfter(serverSeenLamport);

    final pushEnvelope = await _cryptoService.encryptEnvelope(
      senderDeviceId: localProfile.deviceId,
      keyBase64: trusted.sharedKey!,
      payload: {
        'type': 'sync_push',
        'requesterDeviceId': localProfile.deviceId,
        'ops': localOps.map((e) => e.toMap()).toList(),
      },
    );

    final pushResponseEnvelope = await _syncClient.send(
      host: device.host,
      port: device.port,
      message: pushEnvelope,
    );

    final pushResponse = await _decryptIfSecure(
      pushResponseEnvelope,
      trusted.sharedKey!,
    );
    if (pushResponse['type'] != 'sync_push_ok') {
      AppLog.w('sync-engine', 'sync push rejected: ${pushResponse['message']}');
      throw Exception(
        (pushResponse['message'] as String?) ?? 'Sync push failed',
      );
    }
    AppLog.i(
      'sync-engine',
      'sync finished, pushed ${localOps.length} op(s), remote ack ${pushResponse['applied']}',
    );
  }

  /// 与已配对设备实体执行同步。
  Future<void> syncWithTrustedDevice(DeviceEntity device) async {
    final pseudoDevice = DiscoveredDevice(
      deviceId: device.deviceId,
      displayName: device.displayName,
      host: device.host,
      port: device.port,
      publicKey: device.publicKey,
      lastSeen: DateTime.now().toUtc(),
    );
    await syncWithDevice(pseudoDevice);
  }

  /// 重新配对已信任设备并立即执行连接检查。
  Future<void> reconnectTrustedDevice({
    required DeviceEntity device,
    required String code,
  }) async {
    final discovered = _discoveredById[device.deviceId];
    final endpoint =
        discovered ??
        DiscoveredDevice(
          deviceId: device.deviceId,
          displayName: device.displayName,
          host: device.host,
          port: device.port,
          publicKey: device.publicKey,
          lastSeen: DateTime.now().toUtc(),
        );

    await pairWithDevice(device: endpoint, code: code);
    await _probeTrustedDevice(endpoint, force: true);
  }

  /// 删除已配对设备并清理相关运行期状态。
  Future<void> deleteTrustedDevice(String deviceId) async {
    await _deviceRepository.deleteDevice(deviceId);
    await _appSettingsService.removeDeviceAutoSyncEnabled(deviceId);
    await _appSettingsService.removeDeviceOneTimeConnectionEnabled(deviceId);
    _connectAutoSyncedDeviceIds.remove(deviceId);
    _lastTrustedProbeAttempts.remove(deviceId);
    _probingTrustedDeviceIds.remove(deviceId);
    _trustedById.remove(deviceId);
    _discoveredById.remove(deviceId);
    final next = Map<String, TrustedDeviceConnectionState>.from(
      trustedConnectionStates.value,
    )..remove(deviceId);
    trustedConnectionStates.value = next;
  }

  Future<void> _probeTrustedDevice(
    DiscoveredDevice device, {
    bool force = false,
  }) async {
    final deviceId = device.deviceId;
    final trusted = _trustedById[deviceId];
    if (trusted == null || !trusted.trusted || trusted.sharedKey == null) {
      return;
    }

    final now = DateTime.now().toUtc();
    final lastAttempt = _lastTrustedProbeAttempts[deviceId];
    if (!force &&
        lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(seconds: 8)) {
      return;
    }
    if (_probingTrustedDeviceIds.contains(deviceId)) {
      return;
    }

    _lastTrustedProbeAttempts[deviceId] = now;
    _probingTrustedDeviceIds.add(deviceId);
    final currentState = connectionStateOf(deviceId);
    final shouldShowConnecting =
        force || currentState != TrustedDeviceConnectionState.connected;
    if (shouldShowConnecting) {
      _setTrustedConnectionState(
        deviceId,
        TrustedDeviceConnectionState.connecting,
      );
    }

    try {
      await _syncTrustedSettingsWithPeer(
        trusted: trusted,
        host: device.host,
        port: device.port,
      );
      final wasConnected =
          currentState == TrustedDeviceConnectionState.connected;
      _setTrustedConnectionState(
        deviceId,
        TrustedDeviceConnectionState.connected,
      );
      if (!wasConnected) {
        await _syncOnConnectIfEnabled(trusted);
      }
    } catch (e) {
      AppLog.w(
        'sync-engine',
        'trusted probe failed for ${device.displayName} (${device.host}:${device.port}): $e',
      );
      _connectAutoSyncedDeviceIds.remove(deviceId);
      _setTrustedConnectionState(
        deviceId,
        TrustedDeviceConnectionState.invalid,
      );
    } finally {
      _probingTrustedDeviceIds.remove(deviceId);
    }
  }

  /// 设备首次连通后自动拉推一次增量，同步开关开启时生效。
  Future<void> _syncOnConnectIfEnabled(DeviceEntity trusted) async {
    if (!_appSettingsService.getDeviceAutoSyncEnabled(trusted.deviceId)) {
      return;
    }
    if (_connectAutoSyncedDeviceIds.contains(trusted.deviceId)) {
      return;
    }
    _connectAutoSyncedDeviceIds.add(trusted.deviceId);
    try {
      await syncWithTrustedDevice(trusted);
      AppLog.i(
        'sync-engine',
        'auto sync on connect completed for ${trusted.displayName} (${trusted.deviceId})',
      );
    } catch (e) {
      _connectAutoSyncedDeviceIds.remove(trusted.deviceId);
      AppLog.w(
        'sync-engine',
        'auto sync on connect failed for ${trusted.displayName} (${trusted.deviceId}): $e',
      );
    }
  }

  Future<void> _syncTrustedSettingsWithPeer({
    required DeviceEntity trusted,
    required String host,
    required int port,
  }) async {
    final localProfile = _localDeviceService.profile;
    final localAutoSyncSetting = _appSettingsService.getDeviceAutoSyncSetting(
      trusted.deviceId,
    );
    final localOneTimeSetting = _appSettingsService
        .getDeviceOneTimeConnectionSetting(trusted.deviceId);

    final requestEnvelope = await _cryptoService.encryptEnvelope(
      senderDeviceId: localProfile.deviceId,
      keyBase64: trusted.sharedKey!,
      payload: {
        'type': 'peer_status_request',
        'requesterDeviceId': localProfile.deviceId,
        'autoSyncEnabled': localAutoSyncSetting.enabled,
        'autoSyncUpdatedAtMs':
            localAutoSyncSetting.updatedAt.millisecondsSinceEpoch,
        'oneTimeConnectionEnabled': localOneTimeSetting.enabled,
        'oneTimeConnectionUpdatedAtMs':
            localOneTimeSetting.updatedAt.millisecondsSinceEpoch,
      },
    );

    final responseEnvelope = await _syncClient.send(
      host: host,
      port: port,
      message: requestEnvelope,
    );
    final response = await _decryptIfSecure(
      responseEnvelope,
      trusted.sharedKey!,
    );
    if (response['type'] != 'peer_status_response') {
      throw Exception(
        (response['message'] as String?) ?? 'Peer status request failed',
      );
    }

    final remoteAutoSyncEnabled = response['autoSyncEnabled'] == true;
    final remoteAutoSyncUpdatedAtMs =
        _asInt(response['autoSyncUpdatedAtMs']) ?? 0;
    final remoteAutoSyncUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
      remoteAutoSyncUpdatedAtMs,
      isUtc: true,
    );
    final remoteOneTimeEnabled = response['oneTimeConnectionEnabled'] == true;
    final remoteOneTimeUpdatedAtMs =
        _asInt(response['oneTimeConnectionUpdatedAtMs']) ?? 0;
    final remoteOneTimeUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
      remoteOneTimeUpdatedAtMs,
      isUtc: true,
    );

    final autoSyncUseLocal =
        !remoteAutoSyncUpdatedAt.isAfter(localAutoSyncSetting.updatedAt);
    final oneTimeUseLocal =
        !remoteOneTimeUpdatedAt.isAfter(localOneTimeSetting.updatedAt);

    final targetAutoSyncEnabled =
        autoSyncUseLocal ? localAutoSyncSetting.enabled : remoteAutoSyncEnabled;
    final targetAutoSyncUpdatedAt =
        autoSyncUseLocal
            ? localAutoSyncSetting.updatedAt
            : remoteAutoSyncUpdatedAt;
    final targetOneTimeEnabled =
        oneTimeUseLocal ? localOneTimeSetting.enabled : remoteOneTimeEnabled;
    final targetOneTimeUpdatedAt =
        oneTimeUseLocal
            ? localOneTimeSetting.updatedAt
            : remoteOneTimeUpdatedAt;

    if (!autoSyncUseLocal) {
      await _appSettingsService.setDeviceAutoSyncEnabled(
        trusted.deviceId,
        remoteAutoSyncEnabled,
        updatedAt: remoteAutoSyncUpdatedAt,
      );
    }
    if (!oneTimeUseLocal) {
      await _appSettingsService.setDeviceOneTimeConnectionEnabled(
        trusted.deviceId,
        remoteOneTimeEnabled,
        updatedAt: remoteOneTimeUpdatedAt,
      );
    }

    final remoteNeedsApply =
        remoteAutoSyncEnabled != targetAutoSyncEnabled ||
        remoteAutoSyncUpdatedAtMs !=
            targetAutoSyncUpdatedAt.millisecondsSinceEpoch ||
        remoteOneTimeEnabled != targetOneTimeEnabled ||
        remoteOneTimeUpdatedAtMs !=
            targetOneTimeUpdatedAt.millisecondsSinceEpoch;
    if (!remoteNeedsApply) {
      return;
    }

    final applyEnvelope = await _cryptoService.encryptEnvelope(
      senderDeviceId: localProfile.deviceId,
      keyBase64: trusted.sharedKey!,
      payload: {
        'type': 'peer_settings_apply',
        'requesterDeviceId': localProfile.deviceId,
        'autoSyncEnabled': targetAutoSyncEnabled,
        'autoSyncUpdatedAtMs': targetAutoSyncUpdatedAt.millisecondsSinceEpoch,
        'oneTimeConnectionEnabled': targetOneTimeEnabled,
        'oneTimeConnectionUpdatedAtMs':
            targetOneTimeUpdatedAt.millisecondsSinceEpoch,
      },
    );

    final applyResponseEnvelope = await _syncClient.send(
      host: host,
      port: port,
      message: applyEnvelope,
    );
    final applyResponse = await _decryptIfSecure(
      applyResponseEnvelope,
      trusted.sharedKey!,
    );
    if (applyResponse['type'] != 'peer_settings_apply_ok') {
      throw Exception(
        (applyResponse['message'] as String?) ?? 'Peer settings apply failed',
      );
    }
  }

  void _setTrustedConnectionState(
    String deviceId,
    TrustedDeviceConnectionState state,
  ) {
    final current = trustedConnectionStates.value[deviceId];
    if (current == state) {
      return;
    }
    final next = Map<String, TrustedDeviceConnectionState>.from(
      trustedConnectionStates.value,
    )..[deviceId] = state;
    trustedConnectionStates.value = next;
  }

  /// 处理对端 register 请求并回传本机信息。
  Future<Map<String, dynamic>> _handleRegister(
    Map<String, dynamic> payload,
    InternetAddress remoteAddress,
  ) async {
    final remoteDeviceId = payload['deviceId'] as String?;
    final remoteName = payload['displayName'] as String?;
    final remotePublicKey = payload['publicKey'] as String?;
    final remotePort = _asInt(payload['syncPort']);
    if (remoteDeviceId == null ||
        remoteName == null ||
        remotePublicKey == null ||
        remotePort == null) {
      AppLog.w(
        'sync-engine',
        'invalid register payload from ${remoteAddress.address}',
      );
      return {'status': 'error', 'message': 'invalid register payload'};
    }

    _discoveryService.upsertDevice(
      deviceId: remoteDeviceId,
      displayName: remoteName,
      host: remoteAddress.address,
      port: remotePort,
      publicKey: remotePublicKey,
    );
    await _deviceRepository.upsertSeenDevice(
      deviceId: remoteDeviceId,
      displayName: remoteName,
      host: remoteAddress.address,
      port: remotePort,
      publicKey: remotePublicKey,
    );
    AppLog.i(
      'sync-engine',
      'accepted register from $remoteName (${remoteAddress.address}:$remotePort)',
    );

    final profile = _localDeviceService.profile;
    return {
      'status': 'ok',
      'deviceId': profile.deviceId,
      'displayName': profile.displayName,
      'publicKey': profile.publicKey,
      'syncPort': AppConstants.syncPort,
    };
  }

  /// 发现设备后按节流策略尝试 register-back，提升跨平台互相可见性。
  Future<void> _registerBackIfNeeded(DiscoveredDevice device) async {
    final now = DateTime.now().toUtc();
    final last = _lastRegisterAttempts[device.deviceId];
    if (last != null && now.difference(last) < const Duration(seconds: 15)) {
      return;
    }
    _lastRegisterAttempts[device.deviceId] = now;

    try {
      final profile = _localDeviceService.profile;
      final response = await _syncClient.register(
        host: device.host,
        port: device.port,
        payload: {
          'deviceId': profile.deviceId,
          'displayName': profile.displayName,
          'publicKey': profile.publicKey,
          'syncPort': AppConstants.syncPort,
        },
      );
      if (response['status'] != 'ok') {
        AppLog.w(
          'sync-engine',
          'register back rejected by ${device.host}:${device.port}, response=$response',
        );
        return;
      }

      final responseDeviceId = response['deviceId'] as String?;
      final responseName = response['displayName'] as String?;
      final responsePublicKey = response['publicKey'] as String?;
      final responsePort = _asInt(response['syncPort']);
      if (responseDeviceId == null ||
          responseName == null ||
          responsePublicKey == null ||
          responsePort == null) {
        return;
      }
      _discoveryService.upsertDevice(
        deviceId: responseDeviceId,
        displayName: responseName,
        host: device.host,
        port: responsePort,
        publicKey: responsePublicKey,
      );
      await _deviceRepository.upsertSeenDevice(
        deviceId: responseDeviceId,
        displayName: responseName,
        host: device.host,
        port: responsePort,
        publicKey: responsePublicKey,
      );
      AppLog.i(
        'sync-engine',
        'register back success with ${device.displayName} (${device.host})',
      );
    } catch (e) {
      AppLog.w(
        'sync-engine',
        'register back failed to ${device.host}:${device.port}: $e',
      );
    }
  }

  /// 容错读取整数。
  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  /// 服务端消息统一入口，优先处理 secure_message。
  Future<Map<String, dynamic>> _onServerMessage(
    Map<String, dynamic> message,
    InternetAddress remoteAddress,
  ) async {
    if (message['type'] == 'secure_message') {
      final senderDeviceId = message['deviceId'] as String?;
      if (senderDeviceId == null) {
        return {'type': 'error', 'message': 'Missing sender device id'};
      }

      final trusted = await _deviceRepository.getByDeviceId(senderDeviceId);
      if (trusted == null || !trusted.trusted || trusted.sharedKey == null) {
        AppLog.w(
          'sync-engine',
          'reject secure message from untrusted $senderDeviceId',
        );
        return {'type': 'error', 'message': 'Untrusted device'};
      }

      final plain = await _cryptoService.decryptEnvelope(
        envelope: message,
        keyBase64: trusted.sharedKey!,
      );

      final plainResponse = await _handlePlainMessage(plain, remoteAddress);

      return _cryptoService.encryptEnvelope(
        payload: plainResponse,
        keyBase64: trusted.sharedKey!,
        senderDeviceId: _localDeviceService.profile.deviceId,
      );
    }

    return _handlePlainMessage(message, remoteAddress);
  }

  /// 明文消息路由。
  Future<Map<String, dynamic>> _handlePlainMessage(
    Map<String, dynamic> message,
    InternetAddress remoteAddress,
  ) async {
    final type = message['type'] as String?;
    switch (type) {
      case 'pair_request':
        AppLog.i(
          'sync-engine',
          'received pair_request from ${remoteAddress.address}',
        );
        return _handlePairRequest(message, remoteAddress);
      case 'peer_status_request':
        return _handlePeerStatusRequest(message, remoteAddress);
      case 'peer_settings_apply':
        return _handlePeerSettingsApply(message, remoteAddress);
      case 'sync_request':
        AppLog.i(
          'sync-engine',
          'received sync_request from ${remoteAddress.address}',
        );
        return _handleSyncRequest(message, remoteAddress);
      case 'sync_push':
        AppLog.i(
          'sync-engine',
          'received sync_push from ${remoteAddress.address}',
        );
        return _handleSyncPush(message, remoteAddress);
      default:
        return {'type': 'error', 'message': 'Unsupported message type'};
    }
  }

  /// 处理配对请求并建立信任关系。
  Future<Map<String, dynamic>> _handlePairRequest(
    Map<String, dynamic> message,
    InternetAddress remoteAddress,
  ) async {
    final code = message['code'] as String?;
    if (code == null || code != pairingCode.value) {
      AppLog.w('sync-engine', 'pair request rejected: invalid code');
      return {'type': 'pair_failed', 'message': 'Invalid pairing code'};
    }

    final requesterId = message['deviceId'] as String;
    final requesterName = message['displayName'] as String;
    final requesterPublicKey = message['publicKey'] as String;

    final local = _localDeviceService.profile;
    final sharedKey = await _cryptoService.deriveSharedKey(
      myPrivateKeyBase64: local.privateKey,
      remotePublicKeyBase64: requesterPublicKey,
      pairingCode: code,
    );

    await _deviceRepository.upsertTrustedDevice(
      deviceId: requesterId,
      displayName: requesterName,
      host: remoteAddress.address,
      port: AppConstants.syncPort,
      publicKey: requesterPublicKey,
      sharedKey: sharedKey,
    );
    await _appSettingsService.ensureDeviceAutoSyncEnabled(requesterId);
    await _appSettingsService.ensureDeviceOneTimeConnectionEnabled(requesterId);
    AppLog.i(
      'sync-engine',
      'pair accepted for $requesterName (${remoteAddress.address})',
    );

    return {
      'type': 'pair_ok',
      'deviceId': local.deviceId,
      'displayName': local.displayName,
      'publicKey': local.publicKey,
    };
  }

  /// 处理已配对设备连接检查请求，返回当前设备对该对端的配对设置。
  Future<Map<String, dynamic>> _handlePeerStatusRequest(
    Map<String, dynamic> message,
    InternetAddress remoteAddress,
  ) async {
    final requesterDeviceId = message['requesterDeviceId'] as String?;
    if (requesterDeviceId == null) {
      return {'type': 'error', 'message': 'Missing requesterDeviceId'};
    }

    final requester = await _deviceRepository.getByDeviceId(requesterDeviceId);
    if (requester == null || !requester.trusted) {
      return {'type': 'error', 'message': 'Requester is not trusted'};
    }

    await _appSettingsService.ensureDeviceAutoSyncEnabled(requesterDeviceId);
    await _appSettingsService.ensureDeviceOneTimeConnectionEnabled(
      requesterDeviceId,
    );
    await _deviceRepository.upsertSeenDevice(
      deviceId: requesterDeviceId,
      displayName: requester.displayName,
      host: remoteAddress.address,
      port: requester.port,
      publicKey: requester.publicKey,
    );
    final autoSyncSetting = _appSettingsService.getDeviceAutoSyncSetting(
      requesterDeviceId,
    );
    final oneTimeSetting = _appSettingsService
        .getDeviceOneTimeConnectionSetting(requesterDeviceId);
    return {
      'type': 'peer_status_response',
      'autoSyncEnabled': autoSyncSetting.enabled,
      'autoSyncUpdatedAtMs': autoSyncSetting.updatedAt.millisecondsSinceEpoch,
      'oneTimeConnectionEnabled': oneTimeSetting.enabled,
      'oneTimeConnectionUpdatedAtMs':
          oneTimeSetting.updatedAt.millisecondsSinceEpoch,
    };
  }

  /// 应用对端下发的配对设置。
  Future<Map<String, dynamic>> _handlePeerSettingsApply(
    Map<String, dynamic> message,
    InternetAddress remoteAddress,
  ) async {
    final requesterDeviceId = message['requesterDeviceId'] as String?;
    if (requesterDeviceId == null) {
      return {'type': 'error', 'message': 'Missing requesterDeviceId'};
    }

    final requester = await _deviceRepository.getByDeviceId(requesterDeviceId);
    if (requester == null || !requester.trusted) {
      return {'type': 'error', 'message': 'Requester is not trusted'};
    }

    final autoSyncEnabled = message['autoSyncEnabled'] == true;
    final autoSyncUpdatedAtMs = _asInt(message['autoSyncUpdatedAtMs']) ?? 0;
    final autoSyncUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
      autoSyncUpdatedAtMs,
      isUtc: true,
    );
    final oneTimeEnabled = message['oneTimeConnectionEnabled'] == true;
    final oneTimeUpdatedAtMs =
        _asInt(message['oneTimeConnectionUpdatedAtMs']) ?? 0;
    final oneTimeUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
      oneTimeUpdatedAtMs,
      isUtc: true,
    );
    await _deviceRepository.upsertSeenDevice(
      deviceId: requesterDeviceId,
      displayName: requester.displayName,
      host: remoteAddress.address,
      port: requester.port,
      publicKey: requester.publicKey,
    );
    await _appSettingsService.setDeviceAutoSyncEnabled(
      requesterDeviceId,
      autoSyncEnabled,
      updatedAt: autoSyncUpdatedAt,
    );
    await _appSettingsService.setDeviceOneTimeConnectionEnabled(
      requesterDeviceId,
      oneTimeEnabled,
      updatedAt: oneTimeUpdatedAt,
    );
    return {
      'type': 'peer_settings_apply_ok',
      'autoSyncEnabled': autoSyncEnabled,
      'autoSyncUpdatedAtMs': autoSyncUpdatedAt.millisecondsSinceEpoch,
      'oneTimeConnectionEnabled': oneTimeEnabled,
      'oneTimeConnectionUpdatedAtMs': oneTimeUpdatedAt.millisecondsSinceEpoch,
    };
  }

  /// 处理远端拉取请求，返回本端增量操作。
  Future<Map<String, dynamic>> _handleSyncRequest(
    Map<String, dynamic> message,
    InternetAddress remoteAddress,
  ) async {
    final requesterDeviceId = message['requesterDeviceId'] as String;
    final requester = await _deviceRepository.getByDeviceId(requesterDeviceId);
    if (requester == null || !requester.trusted) {
      AppLog.w(
        'sync-engine',
        'sync_request rejected from untrusted $requesterDeviceId',
      );
      return {'type': 'sync_error', 'message': 'Requester is not trusted'};
    }
    await _appSettingsService.ensureDeviceAutoSyncEnabled(requesterDeviceId);
    await _appSettingsService.ensureDeviceOneTimeConnectionEnabled(
      requesterDeviceId,
    );

    await _deviceRepository.upsertSeenDevice(
      deviceId: requesterDeviceId,
      displayName: requester.displayName,
      host: remoteAddress.address,
      port: requester.port,
      publicKey: requester.publicKey,
    );

    final lastLamportSeen = message['lastLamportSeen'] as int? ?? 0;
    final ops = await _opLogRepository.getOpsAfter(lastLamportSeen);
    final serverSeenRequesterLamport = await _syncCursorRepository
        .getLastLamportSeen(requesterDeviceId);

    return {
      'type': 'sync_response',
      'ops': ops.map((e) => e.toMap()).toList(),
      'serverSeenRequesterLamport': serverSeenRequesterLamport,
    };
  }

  /// 处理远端推送请求，依次应用操作并更新游标。
  Future<Map<String, dynamic>> _handleSyncPush(
    Map<String, dynamic> message,
    InternetAddress remoteAddress,
  ) async {
    final requesterDeviceId = message['requesterDeviceId'] as String;
    final requester = await _deviceRepository.getByDeviceId(requesterDeviceId);
    if (requester == null || !requester.trusted) {
      AppLog.w(
        'sync-engine',
        'sync_push rejected from untrusted $requesterDeviceId',
      );
      return {'type': 'sync_error', 'message': 'Requester is not trusted'};
    }
    await _appSettingsService.ensureDeviceAutoSyncEnabled(requesterDeviceId);
    await _appSettingsService.ensureDeviceOneTimeConnectionEnabled(
      requesterDeviceId,
    );

    await _deviceRepository.upsertSeenDevice(
      deviceId: requesterDeviceId,
      displayName: requester.displayName,
      host: remoteAddress.address,
      port: requester.port,
      publicKey: requester.publicKey,
    );

    final opsRaw = (message['ops'] as List?) ?? const [];
    var maxLamport = await _syncCursorRepository.getLastLamportSeen(
      requesterDeviceId,
    );
    var applied = 0;

    for (final raw in opsRaw) {
      final op = SyncOperation.fromMap((raw as Map).cast<String, dynamic>());
      final inserted = await _applyRemoteOperation(op);
      if (inserted) {
        applied += 1;
      }
      if (op.lamport > maxLamport) {
        maxLamport = op.lamport;
      }
    }

    await _syncCursorRepository.saveCursor(requesterDeviceId, maxLamport);
    AppLog.i(
      'sync-engine',
      'sync_push applied $applied/${opsRaw.length} op(s) from $requesterDeviceId',
    );

    return {
      'type': 'sync_push_ok',
      'applied': applied,
      'lastLamport': maxLamport,
    };
  }

  /// 幂等应用单条远端操作。
  Future<bool> _applyRemoteOperation(SyncOperation op) async {
    final already = await _opLogRepository.hasOp(op.opId);
    if (already) {
      return false;
    }

    if (op.opType == 'delete') {
      final payload = op.payload;
      final deletedAtRaw = payload['deletedAt'] as String?;
      final deletedAt =
          deletedAtRaw == null
              ? DateTime.now().toUtc()
              : DateTime.parse(deletedAtRaw).toUtc();

      await _noteRepository.softDeleteRemoteNote(
        noteId: op.noteId,
        deletedAt: deletedAt,
        editorDeviceId: payload['lastEditorDeviceId'] as String,
        baseRevision: payload['baseRevision'] as int,
        headRevision: payload['headRevision'] as int,
      );
    } else {
      final outcome = await _noteRepository.applyRemoteSnapshot(op.payload);
      if (outcome.hasInlineConflict) {
        AppLog.w(
          'sync-engine',
          'inline conflict inserted for note ${outcome.noteId} from op ${op.opId}',
        );
      }
    }

    await _opLogRepository.appendOperation(op);
    return true;
  }

  /// 生成下一条 Lamport 值。
  Future<int> _nextLamport() async {
    final max = await _opLogRepository.getMaxLamport();
    return max + 1;
  }

  /// 若响应为安全信封则解密，否则直接返回原始数据。
  Future<Map<String, dynamic>> _decryptIfSecure(
    Map<String, dynamic> response,
    String key,
  ) async {
    if (response['type'] != 'secure_message') {
      return response;
    }

    return _cryptoService.decryptEnvelope(envelope: response, keyBase64: key);
  }
}
