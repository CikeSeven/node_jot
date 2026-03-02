import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/app_services.dart';
import '../../data/isar/collections/device_entity.dart';
import '../../domain/models/discovered_device.dart';
import '../../domain/services/sync_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/ios_card_tile.dart';
import '../../ui/widgets/ios_group_section.dart';
import 'paired_device_settings_page.dart';

final pairedDevicesExpandedProvider = StateProvider<bool>((ref) => true);

/// 设备页。
///
/// 提供发现、配对、直连配对与手动同步能力。
class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final services = ref.watch(appServicesProvider);
    final local = services.localDeviceService.profile;
    final pairedExpanded = ref.watch(pairedDevicesExpandedProvider);

    return Container(
      // 页面背景层。
      decoration: BoxDecoration(
        gradient: AppTheme.pageBackground(Theme.of(context).brightness),
      ),
      child: SafeArea(
        child: ListView(
          // 设备页采用纵向滚动，避免小屏设备内容被截断。
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            8,
          ),
          children: [
            // 页面标题。
            Text(l10n.devices, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.m),
            // 本机信息分组：展示设备 ID 与当前配对码，支持刷新发现。
            IosGroupSection(
              title: local.displayName,
              trailing: TextButton.icon(
                onPressed: () async {
                  await services.syncEngine.refreshDiscovery();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.discoveryRefreshed)),
                    );
                  }
                },
                icon: const Icon(CupertinoIcons.refresh, size: 16),
                label: Text(l10n.refresh),
              ),
              child: Column(
                children: [
                  // 动态配对码行（ValueListenable 驱动）。
                  ValueListenableBuilder<String>(
                    valueListenable: services.syncEngine.pairingCode,
                    builder: (context, code, _) {
                      return IosCardTile(
                        title: l10n.pairingCodeDisplay(code),
                        titleStyle: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                        subtitle: l10n.fourDigitCodeHint,
                        leading: const Icon(
                          CupertinoIcons.number_circle,
                          color: AppColors.navActiveText,
                        ),
                        trailing: TextButton(
                          onPressed:
                              () => services.syncEngine.refreshPairingCode(),
                          child: Text(l10n.refresh),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // 已配对设备分组：可以直接手动同步。
            IosGroupSection(
              title: l10n.pairedDevices,
              trailing: IconButton(
                onPressed: () {
                  ref.read(pairedDevicesExpandedProvider.notifier).state =
                      !pairedExpanded;
                },
                icon: AnimatedRotation(
                  turns: pairedExpanded ? 0 : 0.5,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(CupertinoIcons.chevron_up, size: 18),
                ),
              ),
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                firstCurve: Curves.easeOutCubic,
                secondCurve: Curves.easeInCubic,
                crossFadeState:
                    pairedExpanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                firstChild: StreamBuilder<List<DeviceEntity>>(
                  stream: services.syncEngine.trustedDevices,
                  builder: (context, snapshot) {
                    final paired = snapshot.data ?? const <DeviceEntity>[];
                    if (paired.isEmpty) {
                      // 空态：提示尚未有信任设备。
                      return Text(
                        l10n.noPairedDevicesYet,
                        style: Theme.of(context).textTheme.bodyMedium,
                      );
                    }
                    return Column(
                      // 每个条目对应一个已配对设备操作卡。
                      children:
                          paired
                              .map((device) => _PairedDeviceTile(device: device))
                              .toList(),
                    );
                  },
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ),
            // 已发现设备分组：支持普通配对和直连配对。
            IosGroupSection(
              title: l10n.discovered,
              trailing: TextButton.icon(
                onPressed: () => _showDirectPairDialog(context, services),
                icon: const Icon(CupertinoIcons.link_circle, size: 16),
                label: Text(l10n.directPair),
              ),
              child: StreamBuilder<List<DeviceEntity>>(
                stream: services.syncEngine.trustedDevices,
                builder: (context, trustedSnapshot) {
                  final trustedIds =
                      (trustedSnapshot.data ?? const <DeviceEntity>[])
                          .map((e) => e.deviceId)
                          .toSet();
                  return StreamBuilder<List<DiscoveredDevice>>(
                    stream: services.syncEngine.discoveredDevices,
                    builder: (context, snapshot) {
                      final devices =
                          (snapshot.data ?? const <DiscoveredDevice>[])
                              .where((e) => !trustedIds.contains(e.deviceId))
                              .toList();
                      if (devices.isEmpty) {
                        // 空态：当前局域网未发现未配对节点。
                        return Text(
                          l10n.noDevicesFound,
                          style: Theme.of(context).textTheme.bodyMedium,
                        );
                      }
                      return Column(
                        // 每个条目对应一个发现到的未配对设备。
                        children:
                            devices
                                .map(
                                  (device) =>
                                      _DiscoveredDeviceTile(device: device),
                                )
                                .toList(),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出直连配对对话框（通过 IP + 端口 + 配对码）。
  Future<void> _showDirectPairDialog(
    BuildContext context,
    AppServices services,
  ) async {
    final l10n = context.l10n;
    final hostController = TextEditingController();
    final portController = TextEditingController(text: '45888');
    final codeController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.directPairTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 目标主机 IP。
              TextField(
                controller: hostController,
                decoration: InputDecoration(
                  labelText: l10n.hostIpLabel,
                  hintText: l10n.hostIpHint,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              // 目标端口。
              TextField(
                controller: portController,
                decoration: InputDecoration(labelText: l10n.portLabel),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              // 配对码输入。
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: l10n.pairingCodeInputLabel,
                  hintText: l10n.fourDigitCodeHint,
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.pair),
            ),
          ],
        );
      },
    );

    if (submitted != true) {
      hostController.dispose();
      portController.dispose();
      codeController.dispose();
      return;
    }

    final host = hostController.text.trim();
    final code = codeController.text.trim();
    final port = int.tryParse(portController.text.trim()) ?? 45888;
    hostController.dispose();
    portController.dispose();
    codeController.dispose();
    if (host.isEmpty || !RegExp(r'^\d{4}$').hasMatch(code)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.hostAndCodeRequired)));
      }
      return;
    }

    try {
      await services.syncEngine.pairWithHost(
        host: host,
        port: port,
        code: code,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.directPairSuccess)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.directPairFailedWithReason(e.toString())),
          ),
        );
      }
    }
  }
}

/// 已发现设备条目。
class _DiscoveredDeviceTile extends ConsumerWidget {
  const _DiscoveredDeviceTile({required this.device});

  final DiscoveredDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final services = ref.watch(appServicesProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IosCardTile(
        title: device.displayName,
        subtitle: '${device.host}:${device.port}',
        leading: const Icon(
          CupertinoIcons.desktopcomputer,
          color: AppColors.navActiveText,
        ),
        trailing: Wrap(
          // 两个核心动作：配对 + 同步。
          spacing: 4,
          children: [
            TextButton(
              onPressed: () => _showPairDialog(context, services, device),
              child: Text(l10n.pair),
            ),
            FilledButton.tonal(
              onPressed: () => _sync(context, services, device),
              child: Text(l10n.sync),
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出配对码输入框并执行配对。
  Future<void> _showPairDialog(
    BuildContext context,
    AppServices services,
    DiscoveredDevice device,
  ) async {
    final l10n = context.l10n;
    final paired = await _showFourDigitPairDialog(
      context,
      _FourDigitPairDialog(
        title: l10n.pairWithNamedDevice(device.displayName),
        hint: l10n.fourDigitCodeHint,
        cancelText: l10n.cancel,
        invalidCodeText: l10n.pairCodeInvalid,
        oneTimeConnectionLabel: l10n.oneTimeConnection,
        autoSyncLabel: l10n.autoSync,
        initialOneTimeConnection:
            services.appSettingsService.oneTimeConnectionNotifier.value,
        initialAutoSync: services.appSettingsService.autoSyncNotifier.value,
        onOneTimeConnectionChanged:
            (value) =>
                services.appSettingsService.setOneTimeConnection(value),
        onAutoSyncChanged:
            (value) => services.appSettingsService.setAutoSync(value),
        onSubmit: (code) async {
          try {
            await services.syncEngine.pairWithDevice(device: device, code: code);
            return true;
          } catch (_) {
            return false;
          }
        },
      ),
    );
    if (paired != true) {
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pairingSuccess)));
    }
  }

  Future<bool?> _showFourDigitPairDialog(
    BuildContext context,
    _FourDigitPairDialog dialog,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (_) => dialog,
    );
  }

  /// 触发与目标设备的一次同步。
  Future<void> _sync(
    BuildContext context,
    AppServices services,
    DiscoveredDevice device,
  ) async {
    final l10n = context.l10n;
    try {
      await services.syncEngine.syncWithDevice(device);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.syncDone)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.syncFailedWithReason(e.toString()))),
        );
      }
    }
  }
}

class _FourDigitPairDialog extends StatefulWidget {
  const _FourDigitPairDialog({
    required this.title,
    required this.hint,
    required this.cancelText,
    required this.invalidCodeText,
    required this.oneTimeConnectionLabel,
    required this.autoSyncLabel,
    required this.initialOneTimeConnection,
    required this.initialAutoSync,
    required this.onOneTimeConnectionChanged,
    required this.onAutoSyncChanged,
    required this.onSubmit,
  });

  final String title;
  final String hint;
  final String cancelText;
  final String invalidCodeText;
  final String oneTimeConnectionLabel;
  final String autoSyncLabel;
  final bool initialOneTimeConnection;
  final bool initialAutoSync;
  final Future<void> Function(bool value) onOneTimeConnectionChanged;
  final Future<void> Function(bool value) onAutoSyncChanged;
  final Future<bool> Function(String code) onSubmit;

  @override
  State<_FourDigitPairDialog> createState() => _FourDigitPairDialogState();
}

class _FourDigitPairDialogState extends State<_FourDigitPairDialog> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late bool _oneTimeConnection;
  late bool _autoSync;
  bool _submitting = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (_) => TextEditingController());
    _focusNodes = List.generate(4, (_) => FocusNode());
    _oneTimeConnection = widget.initialOneTimeConnection;
    _autoSync = widget.initialAutoSync;
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _joinedCode => _controllers.map((c) => c.text).join();

  Future<void> _tryAutoSubmit() async {
    if (_submitting || !RegExp(r'^\d{4}$').hasMatch(_joinedCode)) {
      return;
    }

    setState(() {
      _submitting = true;
      _hasError = false;
    });

    final success = await widget.onSubmit(_joinedCode);
    if (!mounted) {
      return;
    }
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes.first.requestFocus();
    setState(() {
      _submitting = false;
      _hasError = true;
    });
  }

  Widget _buildCell(int index) {
    return SizedBox(
      width: 52,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        autofocus: index == 0,
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: index == 3 ? TextInputAction.done : TextInputAction.next,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor:
              _hasError
                  ? Theme.of(context).colorScheme.error.withValues(alpha: 0.08)
                  : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color:
                  _hasError
                      ? Theme.of(context).colorScheme.error
                      : AppColors.borderSoft,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              width: 1.4,
              color:
                  _hasError
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        onChanged: (value) {
          if (_submitting) {
            return;
          }
          if (_hasError) {
            setState(() {
              _hasError = false;
            });
          }
          if (value.isNotEmpty && index < 3) {
            _focusNodes[index + 1].requestFocus();
          }
          unawaited(_tryAutoSubmit());
        },
        onSubmitted: (_) {
          if (_submitting) {
            return;
          }
          unawaited(_tryAutoSubmit());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCell(0),
                const SizedBox(width: 8),
                _buildCell(1),
                const SizedBox(width: 8),
                _buildCell(2),
                const SizedBox(width: 8),
                _buildCell(3),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_submitting) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    _hasError ? widget.invalidCodeText : widget.hint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          _hasError
                              ? Theme.of(context).colorScheme.error
                              : null,
                      fontWeight: _hasError ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _oneTimeConnection,
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(widget.oneTimeConnectionLabel),
              onChanged:
                  _submitting
                      ? null
                      : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _oneTimeConnection = value;
                        });
                        unawaited(widget.onOneTimeConnectionChanged(value));
                      },
            ),
            CheckboxListTile(
              value: _autoSync,
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(widget.autoSyncLabel),
              onChanged:
                  _submitting
                      ? null
                      : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _autoSync = value;
                        });
                        unawaited(widget.onAutoSyncChanged(value));
                      },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: Text(widget.cancelText),
        ),
      ],
    );
  }
}

/// 已配对设备条目。
class _PairedDeviceTile extends ConsumerWidget {
  const _PairedDeviceTile({required this.device});

  final DeviceEntity device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final services = ref.watch(appServicesProvider);
    return ValueListenableBuilder<Map<String, TrustedDeviceConnectionState>>(
      valueListenable: services.syncEngine.trustedConnectionStates,
      builder: (context, states, _) {
        final state =
            states[device.deviceId] ?? TrustedDeviceConnectionState.unknown;
        return ValueListenableBuilder<bool>(
          valueListenable: services.appSettingsService
              .deviceAutoSyncEnabledListenable(device.deviceId),
          builder: (context, autoSyncEnabled, _) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IosCardTile(
                title: device.displayName,
                subtitle:
                    '${device.host}:${device.port} · ${_connectionStateText(l10n, state)}',
                subtitleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      state == TrustedDeviceConnectionState.invalid
                          ? Theme.of(context).colorScheme.error
                          : state == TrustedDeviceConnectionState.connected
                          ? const Color(0xFF6FCF97)
                          : AppColors.textSecondary,
                  fontWeight:
                      state == TrustedDeviceConnectionState.invalid
                          ? FontWeight.w600
                          : FontWeight.w500,
                ),
                leading: const Icon(
                  CupertinoIcons.checkmark_shield,
                  color: AppColors.navActiveText,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PairedDeviceSettingsPage(device: device),
                    ),
                  );
                },
                trailing: _buildTrailingActions(
                  context: context,
                  services: services,
                  state: state,
                  autoSyncEnabled: autoSyncEnabled,
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _connectionStateText(
    AppLocalizations l10n,
    TrustedDeviceConnectionState state,
  ) {
    switch (state) {
      case TrustedDeviceConnectionState.connecting:
        return l10n.connecting;
      case TrustedDeviceConnectionState.connected:
        return l10n.connected;
      case TrustedDeviceConnectionState.invalid:
        return l10n.pairingInvalid;
      case TrustedDeviceConnectionState.unknown:
        return l10n.notConnected;
    }
  }

  Widget _buildTrailingActions({
    required BuildContext context,
    required AppServices services,
    required TrustedDeviceConnectionState state,
    required bool autoSyncEnabled,
  }) {
    final l10n = context.l10n;
    if (state == TrustedDeviceConnectionState.invalid) {
      final colorScheme = Theme.of(context).colorScheme;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 34,
            child: FilledButton.tonalIcon(
              onPressed: () => _reconnect(context, services),
              icon: Icon(CupertinoIcons.arrow_clockwise, size: 14),
              label: Text(l10n.reconnect),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                foregroundColor: colorScheme.error,
                backgroundColor: colorScheme.errorContainer.withValues(
                  alpha: 0.45,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 34,
            height: 34,
            child: OutlinedButton(
              onPressed: () => _deleteDevice(context, services),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(34, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                foregroundColor: colorScheme.error,
                side: BorderSide(
                  color: colorScheme.error.withValues(alpha: 0.45),
                ),
              ),
              child: const Icon(CupertinoIcons.trash, size: 16),
            ),
          ),
        ],
      );
    }

    if (state == TrustedDeviceConnectionState.connected && autoSyncEnabled) {
      return Text(
        l10n.autoSyncEnabledNotice,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    if (state == TrustedDeviceConnectionState.connecting) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return FilledButton.tonal(
      // 一键与信任设备执行增量同步。
      onPressed: () async {
        try {
          await services.syncEngine.syncWithTrustedDevice(device);
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.syncDone)));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.syncFailedWithReason(e.toString()))),
            );
          }
        }
      },
      child: Text(l10n.sync),
    );
  }

  Future<void> _reconnect(BuildContext context, AppServices services) async {
    final l10n = context.l10n;
    final code = await _showReconnectCodeDialog(context, l10n);
    if (code == null) {
      return;
    }

    try {
      await services.syncEngine.reconnectTrustedDevice(device: device, code: code);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.pairingSuccess)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pairingFailedWithReason(e.toString()))),
        );
      }
    }
  }

  Future<void> _deleteDevice(BuildContext context, AppServices services) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(l10n.deleteDevice),
            content: Text(l10n.deleteDeviceConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }

    await services.syncEngine.deleteTrustedDevice(device.deviceId);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.deviceDeleted)));
    }
  }

  Future<String?> _showReconnectCodeDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder:
          (_) => _SimpleFourDigitCodeDialog(
            title: l10n.reconnect,
            hint: l10n.fourDigitCodeHint,
            invalidCodeText: l10n.pairCodeInvalid,
            cancelText: l10n.cancel,
          ),
    );
    return result;
  }
}

class _SimpleFourDigitCodeDialog extends StatefulWidget {
  const _SimpleFourDigitCodeDialog({
    required this.title,
    required this.hint,
    required this.invalidCodeText,
    required this.cancelText,
  });

  final String title;
  final String hint;
  final String invalidCodeText;
  final String cancelText;

  @override
  State<_SimpleFourDigitCodeDialog> createState() =>
      _SimpleFourDigitCodeDialogState();
}

class _SimpleFourDigitCodeDialogState extends State<_SimpleFourDigitCodeDialog> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (_) => TextEditingController());
    _focusNodes = List.generate(4, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((e) => e.text).join();

  void _submitIfComplete() {
    if (RegExp(r'^\d{4}$').hasMatch(_code)) {
      Navigator.of(context).pop(_code);
      return;
    }
    setState(() {
      _hasError = true;
    });
  }

  Widget _buildCell(int index) {
    return SizedBox(
      width: 52,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        autofocus: index == 0,
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor:
              _hasError
                  ? Theme.of(context).colorScheme.error.withValues(alpha: 0.08)
                  : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color:
                  _hasError
                      ? Theme.of(context).colorScheme.error
                      : AppColors.borderSoft,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              width: 1.4,
              color:
                  _hasError
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        onChanged: (value) {
          if (_hasError) {
            setState(() {
              _hasError = false;
            });
          }
          if (value.isNotEmpty && index < 3) {
            _focusNodes[index + 1].requestFocus();
          }
          if (index == 3 && value.isNotEmpty) {
            _submitIfComplete();
          }
        },
        onSubmitted: (_) => _submitIfComplete(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCell(0),
                const SizedBox(width: 8),
                _buildCell(1),
                const SizedBox(width: 8),
                _buildCell(2),
                const SizedBox(width: 8),
                _buildCell(3),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _hasError ? widget.invalidCodeText : widget.hint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _hasError ? Theme.of(context).colorScheme.error : null,
                fontWeight: _hasError ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelText),
        ),
      ],
    );
  }
}
