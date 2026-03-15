import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../core/models/app_services.dart';
import '../l10n/app_localizations.dart';
import '../features/home/home_shell_page.dart';
import 'theme/app_theme.dart';

/// NodeJot 根应用组件。
///
/// 负责注入主题、国际化与首页壳组件，并监听语言切换。
class NodeJotApp extends ConsumerWidget {
  const NodeJotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(appServicesProvider);
    return ValueListenableBuilder<Locale>(
      valueListenable: services.localeService.localeNotifier,
      builder: (context, locale, _) {
        final effectiveLocale =
            locale.languageCode == 'zh' ? const Locale('zh', 'CN') : locale;
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: services.themeService.themeModeNotifier,
          builder: (context, themeMode, _) {
            return MaterialApp(
              title: 'NodeJot',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeMode,
              builder: (context, child) {
                final platformBrightness = MediaQuery.platformBrightnessOf(
                  context,
                );
                final effectiveBrightness =
                    themeMode == ThemeMode.system
                        ? platformBrightness
                        : (themeMode == ThemeMode.dark
                            ? Brightness.dark
                            : Brightness.light);

                return AnnotatedRegion(
                  value: AppTheme.overlayStyleForBrightness(
                    effectiveBrightness,
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
              locale: effectiveLocale,
              supportedLocales: const [
                Locale('en'),
                Locale('zh'),
                Locale('zh', 'CN'),
              ],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                FlutterQuillLocalizations.delegate,
              ],
              home: const HomeShellPage(),
            );
          },
        );
      },
    );
  }
}
