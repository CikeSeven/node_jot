import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/widgets/ios_group_section.dart';

/// 设置页中的“固定配对码”策略区块。
class PairingCodeSection extends StatelessWidget {
  const PairingCodeSection({
    super.key,
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final Future<void> Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IosGroupSection(
      title: l10n.pairingCodeInputLabel,
      child: SwitchListTile.adaptive(
        value: enabled,
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.fixedPairingCode),
        subtitle: Text(l10n.fixedPairingCodeHint),
        onChanged: onChanged,
      ),
    );
  }
}
