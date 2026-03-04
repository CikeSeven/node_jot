import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/note_doc_codec.dart';
import '../../../core/utils/relative_time_formatter.dart';
import '../../../data/isar/collections/note_entity.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/widgets/ios_frosted_panel.dart';

/// 笔记列表卡片组件。
///
/// 布局结构：
/// - 顶部：标题 + 选中态图标；
/// - 中部：正文预览（最多两行）；
/// - 底部：相对更新时间。
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onLongPress,
    required this.selected,
  });

  final NoteEntity note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final displayTitle =
        (note.displayTitleCache ?? '').trim().isEmpty
            ? note.title
            : note.displayTitleCache!;
    final previewText =
        (note.previewTextCache ?? '').trim().isNotEmpty
            ? note.previewTextCache!.trim()
            : NoteDocCodec.extractPreviewText(note.contentMd).trim();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border:
            selected
                ? Border.all(color: colorScheme.primary.withValues(alpha: 0.55))
                : null,
      ),
      child: IosFrostedPanel(
        radius: 16,
        blur: 14,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayTitle,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selected)
                      Icon(
                        CupertinoIcons.check_mark_circled_solid,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                  ],
                ),
                if (previewText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    previewText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      RelativeTimeFormatter.formatUpdatedAt(
                        updatedAt: note.updatedAt,
                        now: DateTime.now(),
                        l10n: l10n,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
