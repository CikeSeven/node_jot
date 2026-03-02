import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/widgets/glass_bottom_nav.dart';
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

    return Scaffold(
      body: Stack(
        children: [
          // 主内容层：承载三个页面（禁用手势滑动，仅通过底栏切换）。
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: pages,
          ),
          // 底栏下的毛玻璃衬底，让页面内容可延伸到底部且不影响可读性。
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomNavBackdrop(),
          ),
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

/// 底栏下方模糊背景层。
///
/// 作用：让内容可以延伸到底部导航下方，同时保持可读性。
class _BottomNavBackdrop extends StatelessWidget {
  const _BottomNavBackdrop();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final height = 100 + bottomInset;

    return IgnorePointer(
      child: ClipRect(
        // 仅在底部区域做背景模糊，避免全屏模糊带来的性能开销。
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
