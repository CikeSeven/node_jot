import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/app_services.dart';
import '../../../domain/models/discovered_device.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/widgets/ios_card_tile.dart';
import '../dialogs/four_digit_pair_dialog.dart';

/// 已发现但未配对设备条目。
///
/// 该条目仅负责“展示 + 发起配对”，不承载同步或设备设置入口。
class DiscoveredDeviceTile extends ConsumerWidget {
  const DiscoveredDeviceTile({super.key, required this.device});

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
          spacing: 4,
          children: [
            TextButton(
              onPressed: () => _showPairDialog(context, services, device),
              child: Text(l10n.pair),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPairDialog(
    BuildContext context,
    AppServices services,
    DiscoveredDevice device,
  ) async {
    final l10n = context.l10n;
    final paired = await showDialog<bool>(
      context: context,
      builder:
          (_) => FourDigitPairDialog(
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
}
