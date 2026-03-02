import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/models/app_services.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/ios_card_tile.dart';
import '../../ui/widgets/ios_group_section.dart';

/// 设置页。
///
/// 当前包含设备名修改与本机身份信息展示。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _nameController;
  bool _saving = false;

  IconData _currentPlatformIcon(BuildContext context) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return CupertinoIcons.desktopcomputer;
      case TargetPlatform.iOS:
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return CupertinoIcons.device_phone_portrait;
    }
  }

  @override
  void initState() {
    super.initState();
    final profile = ref.read(appServicesProvider).localDeviceService.profile;
    _nameController = TextEditingController(text: profile.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final services = ref.watch(appServicesProvider);
    final profile = services.localDeviceService.profile;
    final platformIcon = _currentPlatformIcon(context);

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
          // 设置页采用滚动布局，兼容小屏与软键盘弹起场景。
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            8,
          ),
          children: [
            // 页面标题。
            Text(l10n.settings, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.m),
            // 设备名称编辑分组。
            IosGroupSection(
              title: l10n.deviceName,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 设备名称输入框。
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      prefixIcon: Icon(platformIcon),
                      hintText: l10n.deviceName,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 保存设备名称按钮。
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          _saving
                              ? null
                              : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                setState(() => _saving = true);
                                try {
                                  await services.syncEngine
                                      .updateLocalDisplayName(
                                        _nameController.text,
                                      );
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.saveDeviceNameDone),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _saving = false);
                                  }
                                }
                              },
                      child: Text(_saving ? l10n.saving : l10n.saveDeviceName),
                    ),
                  ),
                ],
              ),
            ),
            // 本机身份信息分组。
            IosGroupSection(
              title: l10n.localProfile,
              child: Column(
                children: [
                  // 设备 ID 展示。
                  IosCardTile(
                    title: l10n.deviceIdLabel(profile.deviceId),
                    leading: const Icon(
                      CupertinoIcons.person_crop_circle_badge_checkmark,
                      color: AppColors.navActiveText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 公钥摘要展示。
                  IosCardTile(
                    title: l10n.publicKeyLabel(
                      '${profile.publicKey.substring(0, 24)}...',
                    ),
                    leading: const Icon(
                      CupertinoIcons.lock_shield,
                      color: AppColors.navActiveText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
