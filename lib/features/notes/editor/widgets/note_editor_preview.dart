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

  final ValueListenable<String> markdownListenable;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: markdownListenable,
      builder: (context, markdown, _) {
        return SingleChildScrollView(
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
