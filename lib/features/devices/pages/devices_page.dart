import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/app_services.dart';
import '../../../l10n/app_localizations.dart';
import '../sections/devices_discovered_section.dart';
import '../sections/devices_local_section.dart';
import '../sections/devices_paired_section.dart';

final pairedDevicesExpandedProvider = StateProvider<bool>((ref) => true);

/// 设备页。
///
/// 页面职责：
/// - 组装本机信息、已配对设备、已发现设备三大布局区块；
/// - 管理“已配对分组”展开状态；
/// - 提供直连配对对话框入口。
class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final services = ref.watch(appServicesProvider);
    final local = services.localDeviceService.profile;
    final pairedExpanded = ref.watch(pairedDevicesExpandedProvider);
    final platform = Theme.of(context).platform;
    final useSideRail =
        platform == TargetPlatform.windows || platform == TargetPlatform.macOS;
    final listBottomOffset =
        useSideRail ? 16.0 : 112 + MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.pageBackground(Theme.of(context).brightness),
      ),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            listBottomOffset,
          ),
          children: [
            // 区块一：页面标题。
            Text(l10n.devices, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.m),
            // 区块二：本机信息与配对码。
            DevicesLocalSection(
              localDisplayName: local.displayName,
              pairingCodeListenable: services.syncEngine.pairingCode,
              onRefreshDiscovery: () async {
                await services.syncEngine.refreshDiscovery();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.discoveryRefreshed)),
                  );
                }
              },
              onRefreshPairingCode: () async {
                await services.syncEngine.refreshPairingCode();
              },
            ),
            // 区块三：已配对设备列表。
            DevicesPairedSection(
              services: services,
              expanded: pairedExpanded,
              onToggleExpanded: () {
                ref.read(pairedDevicesExpandedProvider.notifier).state =
                    !pairedExpanded;
              },
            ),
            // 区块四：已发现设备列表。
            DevicesDiscoveredSection(
              services: services,
              onDirectPair: () => _showDirectPairDialog(context, services),
            ),
          ],
        ),
      ),
    );
  }

  /// 直连配对对话框（IP + 端口 + 配对码）。
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
              TextField(
                controller: hostController,
                decoration: InputDecoration(
                  labelText: l10n.hostIpLabel,
                  hintText: l10n.hostIpHint,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: portController,
                decoration: InputDecoration(labelText: l10n.portLabel),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
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
      await services.syncEngine.pairWithHost(host: host, port: port, code: code);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.directPairSuccess)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.directPairFailedWithReason(e.toString()))),
        );
      }
    }
  }
}
