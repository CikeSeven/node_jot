import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/app_services.dart';
import '../../core/services/theme_service.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/ios_group_section.dart';

/// 设置页。
///
/// 当前包含设备名修改与主题模式设置。
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

  String _themeModeText(AppLocalizations l10n, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return l10n.themeSystem;
      case ThemeMode.light:
        return l10n.themeLight;
      case ThemeMode.dark:
        return l10n.themeDark;
    }
  }

  String _localeText(Locale locale) {
    switch (locale.languageCode) {
      case 'zh':
        return '中文';
      case 'en':
      default:
        return 'English';
    }
  }

  Future<void> _showThemeMenu(
    BuildContext context,
    Offset position, {
    required ThemeMode currentMode,
    required ThemeService themeService,
    required AppLocalizations l10n,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<ThemeMode>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<ThemeMode>(
          value: ThemeMode.system,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.themeSystem),
              if (currentMode == ThemeMode.system)
                Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
        PopupMenuItem<ThemeMode>(
          value: ThemeMode.light,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.themeLight),
              if (currentMode == ThemeMode.light)
                Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
        PopupMenuItem<ThemeMode>(
          value: ThemeMode.dark,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.themeDark),
              if (currentMode == ThemeMode.dark)
                Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ],
    );

    if (selected != null) {
      await themeService.setThemeMode(selected);
    }
  }

  Future<void> _showLanguageMenu(
    BuildContext context,
    Offset position, {
    required Locale currentLocale,
    required AppServices services,
    required AppLocalizations l10n,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<Locale>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<Locale>(
          value: const Locale('zh'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('中文'),
              if (currentLocale.languageCode == 'zh')
                Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
        PopupMenuItem<Locale>(
          value: const Locale('en'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('English'),
              if (currentLocale.languageCode == 'en')
                Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ],
    );

    if (selected != null) {
      await services.localeService.setLocale(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final services = ref.watch(appServicesProvider);
    final themeService = services.themeService;
    final platformIcon = _currentPlatformIcon(context);
    final platform = Theme.of(context).platform;
    final useSideRail =
        platform == TargetPlatform.windows || platform == TargetPlatform.macOS;
    // 与笔记页一致：移动端为悬浮底栏预留安全间距，避免底部内容被遮挡。
    final listBottomOffset =
        useSideRail ? 16.0 : 112 + MediaQuery.paddingOf(context).bottom;

    return Container(
      // 页面背景层。
      decoration: BoxDecoration(
        gradient: AppTheme.pageBackground(Theme.of(context).brightness),
      ),
      child: SafeArea(
        child: ListView(
          // 设置页采用滚动布局，兼容小屏与软键盘弹起场景。
          padding: EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            listBottomOffset,
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
            // 主题与语言合并分组，减少垂直空间占用。
            IosGroupSection(
              title: '${l10n.themeMode} / ${l10n.language}',
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: themeService.themeModeNotifier,
                builder: (context, mode, _) {
                  return ValueListenableBuilder<Locale>(
                    valueListenable: services.localeService.localeNotifier,
                    builder: (context, locale, __) {
                      return Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTapDown: (details) {
                              _showThemeMenu(
                                context,
                                details.globalPosition,
                                currentMode: mode,
                                themeService: themeService,
                                l10n: l10n,
                              );
                            },
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.color_lens_outlined),
                              title: Text(l10n.themeMode),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _themeModeText(l10n, mode),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const Icon(Icons.unfold_more),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTapDown: (details) {
                              _showLanguageMenu(
                                context,
                                details.globalPosition,
                                currentLocale: locale,
                                services: services,
                                l10n: l10n,
                              );
                            },
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.language),
                              title: Text(l10n.language),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _localeText(locale),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const Icon(Icons.unfold_more),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            // 配对码策略分组。
            IosGroupSection(
              title: l10n.pairingCodeInputLabel,
              child: ValueListenableBuilder<bool>(
                valueListenable:
                    services.appSettingsService.fixedPairingCodeEnabledNotifier,
                builder: (context, enabled, _) {
                  return SwitchListTile.adaptive(
                    value: enabled,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.fixedPairingCode),
                    subtitle: Text(l10n.fixedPairingCodeHint),
                    onChanged: (value) async {
                      await services.appSettingsService
                          .setFixedPairingCodeEnabled(
                            value,
                            currentPairingCode:
                                services.syncEngine.pairingCode.value,
                          );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.localFirstDescription,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
