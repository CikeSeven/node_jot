import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_effects.dart';
import '../../app/theme/app_radii.dart';

/// iOS 风格毛玻璃面板。
///
/// 提供统一圆角、阴影、边框和背景模糊效果。
class IosFrostedPanel extends StatelessWidget {
  const IosFrostedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = AppRadii.card,
    this.blur = 18,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      // 外层：仅负责圆角阴影，制造悬浮感。
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppEffects.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          // 中层：背景模糊（毛玻璃核心）。
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              // 内层：半透明渐变面 + 细边框，提升玻璃质感。
              gradient:
                  gradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors:
                        isDark
                            ? const [Color(0xCC2A2D3C), Color(0xB3242735)]
                            : const [Color(0xC2FFFFFF), Color(0xB8F7F2FF)],
                  ),
              border: Border.all(
                color:
                    (isDark ? AppColors.borderSoftDark : AppColors.borderSoft)
                        .withValues(alpha: 0.72),
              ),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
