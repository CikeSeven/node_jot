import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_effects.dart';
import '../../app/theme/app_radii.dart';

/// 底部导航栏单项配置。
class GlassBottomNavItem {
  const GlassBottomNavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// 悬浮毛玻璃底部导航栏。
///
/// 支持：
/// - 浮动选中胶囊；
/// - 与 PageView 联动的平滑过渡动画；
/// - 无波纹点击反馈（避免颜色叠加）。
class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.pageProgress,
    required this.onTap,
  });

  final List<GlassBottomNavItem> items;
  final int selectedIndex;
  final double pageProgress;
  final ValueChanged<int> onTap;

  /// 导航容器本体高度（不含 SafeArea 与外部边距）。
  static const double barHeight = 76;

  /// 底部最小外边距（与屏幕边缘留白）。
  static const double bottomMinimumInset = 12;

  /// 移动端底部导航占用高度（含安全区）。
  static double occupiedHeight(BuildContext context) {
    return barHeight +
        bottomMinimumInset +
        MediaQuery.paddingOf(context).bottom;
  }

  @override
  Widget build(BuildContext context) {
    // 将外部传入进度限制在合法区间，避免动画越界。
    final clampedProgress = pageProgress.clamp(
      0.0,
      (items.length - 1).toDouble(),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navTopColor =
        isDark
            ? Color.alphaBlend(
              AppColors.accent.withValues(alpha: 0.20),
              const Color(0xCC212531),
            )
            : Color.alphaBlend(
              AppColors.primary.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0.86),
            );
    final navBottomColor =
        isDark
            ? Color.alphaBlend(
              AppColors.primary.withValues(alpha: 0.16),
              const Color(0xB01E222E),
            )
            : Color.alphaBlend(
              AppColors.primarySoft.withValues(alpha: 0.72),
              const Color(0xBDE9E1FF),
            );
    final navBorderColor =
        isDark
            ? AppColors.borderSoftDark.withValues(alpha: 0.72)
            : AppColors.borderSoft.withValues(alpha: 0.78);
    final inactiveItemColor =
        isDark
            ? AppColors.textSecondaryDark.withValues(alpha: 0.88)
            : const Color(0xFF6D6487);
    final activeIconColor =
        isDark ? const Color(0xFFD8C9FF) : const Color(0xFF4E33B8);
    final activeLabelColor =
        isDark ? const Color(0xFFF1EAFF) : const Color(0xFF2B1A66);
    final selectedPillColor =
        isDark
            ? Color.alphaBlend(
              AppColors.accent.withValues(alpha: 0.34),
              AppColors.surfaceSoftDark.withValues(alpha: 0.88),
            )
            : Color.alphaBlend(
              AppColors.primary.withValues(alpha: 0.42),
              AppColors.primarySoft.withValues(alpha: 0.96),
            );
    final navShadow = <BoxShadow>[
      ...AppEffects.softShadow,
      BoxShadow(
        color: (isDark ? Colors.black : const Color(0xFF5B4E7C)).withValues(
          alpha: isDark ? 0.32 : 0.16,
        ),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
    ];

    return SafeArea(
      // 悬浮底栏与屏幕边缘保留视觉呼吸感。
      minimum: const EdgeInsets.only(
        bottom: bottomMinimumInset,
        left: 16,
        right: 16,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.nav),
          boxShadow: navShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.nav),
          child: BackdropFilter(
            // 导航容器毛玻璃模糊层。
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: barHeight,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [navTopColor, navBottomColor],
                ),
                border: Border.all(color: navBorderColor, width: 1.15),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 根据可用宽度实时计算每个 item 的占位宽度。
                  final itemWidth = constraints.maxWidth / items.length;
                  // 选中胶囊位置由 pageProgress 驱动，实现平滑滑动。
                  final sliderLeft = clampedProgress * itemWidth + 4;
                  final sliderWidth = itemWidth - 8;

                  return Stack(
                    children: [
                      // 选中态背景胶囊（位于按钮层下方）。
                      Positioned(
                        left: sliderLeft,
                        top: 0,
                        bottom: 0,
                        width: sliderWidth,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: selectedPillColor,
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(items.length, (index) {
                          final item = items[index];
                          // 按与当前进度的距离插值颜色和缩放。
                          final distance = (index - clampedProgress)
                              .abs()
                              .clamp(0.0, 1.0);
                          final t = 1 - distance;
                          final iconColor =
                              Color.lerp(
                                inactiveItemColor,
                                activeIconColor,
                                t,
                              )!;
                          final labelColor =
                              Color.lerp(
                                inactiveItemColor,
                                activeLabelColor,
                                t,
                              )!;
                          final scale = 1 + (0.03 * t);
                          final weight =
                              t > 0.55 ? FontWeight.w700 : FontWeight.w600;

                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onTap(index),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    // 图标层。
                                    Transform.scale(
                                      scale: scale,
                                      child: Icon(
                                        item.icon,
                                        color: iconColor,
                                        size: 19,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // 文本标签层。
                                    Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        height: 1,
                                        letterSpacing: 0.2,
                                        fontWeight: weight,
                                        color: labelColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
