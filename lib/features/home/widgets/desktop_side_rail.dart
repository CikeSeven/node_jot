import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../ui/widgets/glass_bottom_nav.dart';
import '../../../ui/widgets/ios_frosted_panel.dart';

/// 桌面端侧栏导航组件。
///
/// 该组件是移动端底部导航的桌面等价实现，保持同一套导航项语义。
class DesktopSideRail extends StatelessWidget {
  const DesktopSideRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<GlassBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return IosFrostedPanel(
      radius: 26,
      blur: 18,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onTap,
        labelType: NavigationRailLabelType.all,
        useIndicator: true,
        indicatorColor: AppColors.primarySoft.withValues(alpha: 0.9),
        selectedIconTheme: const IconThemeData(
          color: AppColors.navActiveText,
          size: 22,
        ),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.navInactive,
          size: 20,
        ),
        selectedLabelTextStyle: const TextStyle(
          color: AppColors.navActiveLabel,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: AppColors.navInactive,
          fontWeight: FontWeight.w600,
        ),
        destinations:
            items
                .map(
                  (item) => NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.icon),
                    label: Text(item.label),
                  ),
                )
                .toList(),
      ),
    );
  }
}
