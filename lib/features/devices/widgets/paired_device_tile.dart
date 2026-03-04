import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/app_services.dart';
import '../../../data/isar/collections/device_entity.dart';
import '../../../domain/services/sync_engine.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/widgets/ios_card_tile.dart';
import '../dialogs/simple_four_digit_code_dialog.dart';
import '../paired_device_settings_page.dart';

/// 已配对设备条目。
///
/// 包含：
/// - 连接状态显示；
/// - 自动同步状态提示；
/// - 重连/删除/手动同步等操作入口。
class PairedDeviceTile extends ConsumerWidget {
  const PairedDeviceTile({super.key, required this.device});

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
              icon: const Icon(CupertinoIcons.arrow_clockwise, size: 14),
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

    if (state == TrustedDeviceConnectionState.unknown) {
      return const SizedBox.shrink();
    }

    return FilledButton.tonal(
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
    final code = await showDialog<String>(
      context: context,
      builder:
          (_) => SimpleFourDigitCodeDialog(
            title: l10n.reconnect,
            hint: l10n.fourDigitCodeHint,
            invalidCodeText: l10n.pairCodeInvalid,
            cancelText: l10n.cancel,
          ),
    );
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
}
