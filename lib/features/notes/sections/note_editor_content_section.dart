import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';

/// 编辑器内容区块。
///
/// 仅负责布局容器：
/// - 外层统一边距；
/// - 用户滚动事件监听；
/// - 将具体编辑器 Widget 作为 child 注入。
class NoteEditorContentSection extends StatelessWidget {
  const NoteEditorContentSection({
    super.key,
    this.topPadding = 0,
    required this.bottomPadding,
    required this.onUserScroll,
    required this.child,
  });

  final double topPadding;
  final double bottomPadding;
  final NotificationListenerCallback<UserScrollNotification> onUserScroll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.l,
        topPadding,
        AppSpacing.l,
        bottomPadding,
      ),
      child: NotificationListener<UserScrollNotification>(
        onNotification: onUserScroll,
        child: child,
      ),
    );
  }
}
