import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../ui/widgets/ios_frosted_panel.dart';

/// Markdown 预览层。
///
/// 当前版本使用轻量文本预览（不做富渲染），重点保证：
/// - 可快速切换；
/// - 大文本下滚动稳定；
/// - 与编辑态共用同一份文档数据。
class NoteEditorPreview extends StatelessWidget {
  const NoteEditorPreview({
    super.key,
    required this.markdownListenable,
    required this.scrollController,
  });

  /// 来自编辑控制器的 markdown 文本监听器。
  final ValueListenable<String> markdownListenable;

  /// 预览滚动控制器（用于保留切换前后的滚动位置）。
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: markdownListenable,
      builder: (context, markdown, _) {
        return SingleChildScrollView(
          // 保留底部额外空间，避免与悬浮状态卡片视觉重叠。
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.xxl,
          ),
          child: IosFrostedPanel(
            radius: 20,
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              // 预览层当前为“纯文本可选择”模式，便于复制与调试；
              // 后续若接入富文本 markdown 渲染，可在此处替换组件。
              markdown,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
          ),
        );
      },
    );
  }
}
