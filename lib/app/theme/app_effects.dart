import 'package:flutter/material.dart';

/// 通用视觉效果令牌。
class AppEffects {
  /// 柔和阴影，主要用于毛玻璃卡片与悬浮导航。
  static List<BoxShadow> softShadow = const [
    BoxShadow(color: Color(0x1A7D6AB5), blurRadius: 24, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0D8D79C7), blurRadius: 8, offset: Offset(0, 3)),
  ];
}
