import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/glass_bottom_nav.dart';
import '../../ui/widgets/ios_frosted_panel.dart';
import '../devices/devices_page.dart';
import '../notes/notes_page.dart';
import '../settings/settings_page.dart';

/// 应用首页壳。
///
/// 包含页面容器、底部导航和切页动画。
class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  static const _animDuration = Duration(milliseconds: 280);
  static const _animCurve = Curves.easeOutCubic;

  late final PageController _pageController;
  int _currentIndex = 0;
  double _pageProgress = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _pageController.addListener(_onPageScroll);
  }

  /// 监听 PageController 的滚动进度，用于驱动底栏联动动画。
  void _onPageScroll() {
    final value = _pageController.page ?? _currentIndex.toDouble();
    if ((value - _pageProgress).abs() < 0.0001) {
      return;
    }
    setState(() {
      _pageProgress = value;
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  /// 底栏点击后的页面切换动画。
  void _onTapNav(int index) {
    if (index == _currentIndex) {
      return;
    }
    _pageController.animateToPage(
      index,
      duration: _animDuration,
      curve: _animCurve,
    );
  }

  bool _useSideRail(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS;
  }

  Widget _buildPageView(List<Widget> pages) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      children: pages,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 三个主 Tab 页，通过 PageView 做动画切换。
    final pages = <Widget>[
      const _KeepAlivePage(
        child: NotesPage(key: PageStorageKey<String>('tab_notes')),
      ),
      const _KeepAlivePage(
        child: DevicesPage(key: PageStorageKey<String>('tab_devices')),
      ),
      const _KeepAlivePage(
        child: SettingsPage(key: PageStorageKey<String>('tab_settings')),
      ),
    ];
    final useSideRail = _useSideRail(context);

    // 底栏配置，顺序与 PageView 页面索引一一对应。
    final navItems = [
      GlassBottomNavItem(
        label: context.l10n.tabNotes,
        icon: CupertinoIcons.doc_text,
      ),
      GlassBottomNavItem(
        label: context.l10n.tabDevices,
        icon: CupertinoIcons.dot_radiowaves_left_right,
      ),
      GlassBottomNavItem(
        label: context.l10n.tabSettings,
        icon: CupertinoIcons.gear,
      ),
    ];

    if (useSideRail) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                child: _DesktopSideRail(
                  items: navItems,
                  selectedIndex: _currentIndex,
                  onTap: _onTapNav,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPageView(pages),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 主内容层：承载三个页面（禁用手势滑动，仅通过底栏切换）。
          _buildPageView(pages),
          // 悬浮底部导航栏。
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassBottomNav(
              items: navItems,
              selectedIndex: _currentIndex,
              pageProgress: _pageProgress,
              onTap: _onTapNav,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSideRail extends StatelessWidget {
  const _DesktopSideRail({
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

/// 为 Tab 页面提供保活能力，避免切页丢失滚动状态。
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
