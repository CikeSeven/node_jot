import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/widgets/ios_group_section.dart';

/// 设置页中的“设备名称”区块。
///
/// 布局包含：
/// - 名称输入框；
/// - 保存按钮。
class DeviceNameSection extends StatelessWidget {
  const DeviceNameSection({
    super.key,
    required this.controller,
    required this.saving,
    required this.platformIcon,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool saving;
  final IconData platformIcon;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IosGroupSection(
      title: l10n.deviceName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              prefixIcon: Icon(platformIcon),
              hintText: l10n.deviceName,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving ? null : () => onSave(),
              child: Text(saving ? l10n.saving : l10n.saveDeviceName),
            ),
          ),
        ],
      ),
    );
  }
}
