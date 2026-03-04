import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/widgets/ios_card_tile.dart';
import '../../../ui/widgets/ios_group_section.dart';

/// 设备页中的“本机信息”区块。
///
/// 显示本机名称、当前配对码，并提供发现刷新入口。
class DevicesLocalSection extends StatelessWidget {
  const DevicesLocalSection({
    super.key,
    required this.localDisplayName,
    required this.pairingCodeListenable,
    required this.onRefreshDiscovery,
    required this.onRefreshPairingCode,
  });

  final String localDisplayName;
  final ValueListenable<String> pairingCodeListenable;
  final Future<void> Function() onRefreshDiscovery;
  final Future<void> Function() onRefreshPairingCode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IosGroupSection(
      title: localDisplayName,
      trailing: TextButton.icon(
        onPressed: () => onRefreshDiscovery(),
        icon: const Icon(CupertinoIcons.refresh, size: 16),
        label: Text(l10n.refresh),
      ),
      child: Column(
        children: [
          ValueListenableBuilder<String>(
            valueListenable: pairingCodeListenable,
            builder: (context, code, _) {
              return IosCardTile(
                title: l10n.pairingCodeDisplay(code),
                titleStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                subtitle: l10n.fourDigitCodeHint,
                leading: const Icon(
                  CupertinoIcons.number_circle,
                  color: AppColors.navActiveText,
                ),
                trailing: TextButton(
                  onPressed: () => onRefreshPairingCode(),
                  child: Text(l10n.refresh),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
