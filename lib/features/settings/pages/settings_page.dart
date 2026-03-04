import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/app_services.dart';
import '../../../core/services/theme_service.dart';
import '../../../l10n/app_localizations.dart';
import '../sections/appearance_language_section.dart';
import '../sections/device_name_section.dart';
import '../sections/pairing_code_section.dart';

/// 设置页。
///
/// 页面职责：
/// - 管理设备名称保存状态；
/// - 调度主题/语言弹出菜单；
/// - 组装设置区块布局。
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

  Future<void> _saveLocalDeviceName(AppServices services) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await services.syncEngine.updateLocalDisplayName(_nameController.text);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.saveDeviceNameDone)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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
            Text(l10n.settings, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.m),
            // 区块二：设备名称设置。
            DeviceNameSection(
              controller: _nameController,
              saving: _saving,
              platformIcon: platformIcon,
              onSave: () => _saveLocalDeviceName(services),
            ),
            // 区块三：外观和语言设置。
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeService.themeModeNotifier,
              builder: (context, mode, _) {
                return ValueListenableBuilder<Locale>(
                  valueListenable: services.localeService.localeNotifier,
                  builder: (context, locale, __) {
                    return AppearanceLanguageSection(
                      themeLabel: _themeModeText(l10n, mode),
                      languageLabel: _localeText(locale),
                      onShowThemeMenu:
                          (position) => _showThemeMenu(
                            context,
                            position,
                            currentMode: mode,
                            themeService: themeService,
                            l10n: l10n,
                          ),
                      onShowLanguageMenu:
                          (position) => _showLanguageMenu(
                            context,
                            position,
                            currentLocale: locale,
                            services: services,
                          ),
                    );
                  },
                );
              },
            ),
            // 区块四：配对码策略。
            ValueListenableBuilder<bool>(
              valueListenable:
                  services.appSettingsService.fixedPairingCodeEnabledNotifier,
              builder: (context, enabled, _) {
                return PairingCodeSection(
                  enabled: enabled,
                  onChanged:
                      (value) => services.appSettingsService
                          .setFixedPairingCodeEnabled(
                            value,
                            currentPairingCode:
                                services.syncEngine.pairingCode.value,
                          ),
                );
              },
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
