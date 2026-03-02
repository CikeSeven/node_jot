import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        return MaterialApp(
          title: 'NodeJot',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: const HomeShellPage(),
        );
      },
    );
  }
}
