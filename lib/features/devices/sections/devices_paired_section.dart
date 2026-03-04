import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/models/app_services.dart';
import '../../../data/isar/collections/device_entity.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/widgets/ios_group_section.dart';
import '../widgets/paired_device_tile.dart';

/// 设备页中的“已配对设备”区块。
///
/// 提供展开/收起、流式列表展示和空状态提示。
class DevicesPairedSection extends StatelessWidget {
  const DevicesPairedSection({
    super.key,
    required this.services,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final AppServices services;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IosGroupSection(
      title: l10n.pairedDevices,
      trailing: IconButton(
        onPressed: onToggleExpanded,
        icon: AnimatedRotation(
          turns: expanded ? 0 : 0.5,
          duration: const Duration(milliseconds: 180),
          child: const Icon(CupertinoIcons.chevron_up, size: 18),
        ),
      ),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 220),
        firstCurve: Curves.easeOutCubic,
        secondCurve: Curves.easeInCubic,
        crossFadeState:
            expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        firstChild: StreamBuilder<List<DeviceEntity>>(
          stream: services.syncEngine.trustedDevices,
          builder: (context, snapshot) {
            final paired = snapshot.data ?? const <DeviceEntity>[];
            if (paired.isEmpty) {
              return Text(
                l10n.noPairedDevicesYet,
                style: Theme.of(context).textTheme.bodyMedium,
              );
            }
            return Column(
              children:
                  paired
                      .map((device) => PairedDeviceTile(device: device))
                      .toList(),
            );
          },
        ),
        secondChild: const SizedBox.shrink(),
      ),
    );
  }
}
