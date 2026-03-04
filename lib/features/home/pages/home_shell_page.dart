import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/widgets/glass_bottom_nav.dart';
import '../../devices/devices_page.dart';
import '../../notes/notes_page.dart';
import '../../settings/settings_page.dart';
import '../widgets/desktop_side_rail.dart';
import '../widgets/keep_alive_page.dart';

/// 应用首页壳。
///
/// 页面职责：
/// - 管理三大主 Tab 的容器与切换动画；
/// - 在移动端显示悬浮底部导航；
/// - 在桌面端切换为侧栏导航。
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

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  /// 监听滚动进度，驱动底栏激活态动画过渡。
  void _onPageScroll() {
    final value = _pageController.page ?? _currentIndex.toDouble();
    if ((value - _pageProgress).abs() < 0.0001) {
      return;
    }
    setState(() {
      _pageProgress = value;
    });
  }

  /// 底栏/侧栏点击后触发页面切换动画。
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

  /// 三页内容容器（禁用手势滑动，仅通过导航切换）。
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
    final pages = <Widget>[
      const KeepAlivePage(
        child: NotesPage(key: PageStorageKey<String>('tab_notes')),
      ),
      const KeepAlivePage(
        child: DevicesPage(key: PageStorageKey<String>('tab_devices')),
      ),
      const KeepAlivePage(
        child: SettingsPage(key: PageStorageKey<String>('tab_settings')),
      ),
    ];
    final useSideRail = _useSideRail(context);

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

    // 桌面布局：左侧导航栏 + 右侧页面区域。
    if (useSideRail) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                child: DesktopSideRail(
                  items: navItems,
                  selectedIndex: _currentIndex,
                  onTap: _onTapNav,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildPageView(pages)),
            ],
          ),
        ),
      );
    }

    // 移动布局：内容层 + 悬浮底部导航。
    return Scaffold(
      body: Stack(
        children: [
          _buildPageView(pages),
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
