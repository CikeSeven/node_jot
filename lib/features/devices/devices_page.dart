import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/models/app_services.dart';
import '../../data/isar/collections/device_entity.dart';
import '../../domain/models/discovered_device.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/ios_card_tile.dart';
import '../../ui/widgets/ios_group_section.dart';

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

    return Container(
      // 页面背景层。
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
        ),
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
                  // 本机设备标识行。
                  IosCardTile(
                    title: l10n.deviceIdLabel(local.deviceId.substring(0, 8)),
                    subtitle: l10n.pairingCodeHint,
                    leading: const Icon(
                      CupertinoIcons.device_phone_portrait,
                      color: AppColors.navActiveText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 动态配对码行（ValueListenable 驱动）。
                  ValueListenableBuilder<String>(
                    valueListenable: services.syncEngine.pairingCode,
                    builder: (context, code, _) {
                      return IosCardTile(
                        title: l10n.pairingCodeDisplay(code),
                        subtitle: l10n.sixDigitCodeHint,
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
              child: StreamBuilder<List<DeviceEntity>>(
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
            ),
            // 已发现设备分组：支持普通配对和直连配对。
            IosGroupSection(
              title: l10n.discovered,
              trailing: TextButton.icon(
                onPressed: () => _showDirectPairDialog(context, services),
                icon: const Icon(CupertinoIcons.link_circle, size: 16),
                label: Text(l10n.directPair),
              ),
              child: StreamBuilder<List<DiscoveredDevice>>(
                stream: services.syncEngine.discoveredDevices,
                builder: (context, snapshot) {
                  final devices = snapshot.data ?? const <DiscoveredDevice>[];
                  if (devices.isEmpty) {
                    // 空态：当前局域网未发现节点。
                    return Text(
                      l10n.noDevicesFound,
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                  }
                  return Column(
                    // 每个条目对应一个发现到的设备。
                    children:
                        devices
                            .map(
                              (device) => _DiscoveredDeviceTile(device: device),
                            )
                            .toList(),
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
                ),
                keyboardType: TextInputType.number,
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
      return;
    }

    final host = hostController.text.trim();
    final code = codeController.text.trim();
    final port = int.tryParse(portController.text.trim()) ?? 45888;
    if (host.isEmpty || code.isEmpty) {
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
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.pairWithDevice),
          // 弹窗主体：输入对端展示的 6 位配对码。
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: l10n.sixDigitCodeHint),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.of(context).pop(controller.text.trim()),
              child: Text(l10n.pair),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) {
      return;
    }
    try {
      await services.syncEngine.pairWithDevice(device: device, code: result);
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

/// 已配对设备条目。
class _PairedDeviceTile extends ConsumerWidget {
  const _PairedDeviceTile({required this.device});

  final DeviceEntity device;

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
          CupertinoIcons.checkmark_shield,
          color: AppColors.navActiveText,
        ),
        trailing: FilledButton.tonal(
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
                  SnackBar(
                    content: Text(l10n.syncFailedWithReason(e.toString())),
                  ),
                );
              }
            }
          },
          child: Text(l10n.sync),
        ),
      ),
    );
  }
}
