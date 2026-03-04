import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/models/app_services.dart';
import '../../../data/isar/collections/device_entity.dart';
import '../../../domain/models/discovered_device.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/widgets/ios_group_section.dart';
import '../widgets/discovered_device_tile.dart';

/// 设备页中的“已发现设备”区块。
///
/// 仅展示未配对设备，并提供直连配对入口。
class DevicesDiscoveredSection extends StatelessWidget {
  const DevicesDiscoveredSection({
    super.key,
    required this.services,
    required this.onDirectPair,
  });

  final AppServices services;
  final Future<void> Function() onDirectPair;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IosGroupSection(
      title: l10n.discovered,
      trailing: TextButton.icon(
        onPressed: () => onDirectPair(),
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
                return Text(
                  l10n.noDevicesFound,
                  style: Theme.of(context).textTheme.bodyMedium,
                );
              }
              return Column(
                children:
                    devices
                        .map((device) => DiscoveredDeviceTile(device: device))
                        .toList(),
              );
            },
          );
        },
      ),
    );
  }
}
