import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/widgets/ios_group_section.dart';

/// 设置页中的“主题/语言”组合区块。
///
/// 设计目的：
/// - 合并两个高频偏好项，减少页面纵向占用；
/// - 使用点击行触发菜单选择，保持一致交互模型。
class AppearanceLanguageSection extends StatelessWidget {
  const AppearanceLanguageSection({
    super.key,
    required this.themeLabel,
    required this.languageLabel,
    required this.onShowThemeMenu,
    required this.onShowLanguageMenu,
  });

  final String themeLabel;
  final String languageLabel;
  final void Function(Offset globalPosition) onShowThemeMenu;
  final void Function(Offset globalPosition) onShowLanguageMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IosGroupSection(
      title: '${l10n.themeMode} / ${l10n.language}',
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTapDown: (details) => onShowThemeMenu(details.globalPosition),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.color_lens_outlined),
              title: Text(l10n.themeMode),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(themeLabel, style: const TextStyle(fontSize: 14)),
                  const Icon(Icons.unfold_more),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTapDown: (details) => onShowLanguageMenu(details.globalPosition),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language),
              title: Text(l10n.language),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(languageLabel, style: const TextStyle(fontSize: 14)),
                  const Icon(Icons.unfold_more),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
