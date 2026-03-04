import 'package:flutter/material.dart';

import '../../../core/utils/note_doc_codec.dart';
import '../../../core/utils/relative_time_formatter.dart';
import '../../../data/isar/collections/note_entity.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/widgets/ios_frosted_panel.dart';

/// 归档列表专用笔记卡片。
///
/// 与主列表卡片不同点：
/// - 预览行数放宽为 3 行；
/// - 默认不展示多选/选中态 UI。
class ArchivedNoteCard extends StatelessWidget {
  const ArchivedNoteCard({super.key, required this.note, required this.onTap});

  final NoteEntity note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final displayTitle =
        (note.displayTitleCache ?? '').trim().isEmpty
            ? note.title
            : note.displayTitleCache!;
    final previewText =
        (note.previewTextCache ?? '').trim().isNotEmpty
            ? note.previewTextCache!.trim()
            : NoteDocCodec.extractPreviewText(note.contentMd).trim();

    return SizedBox(
      width: double.infinity,
      child: IosFrostedPanel(
        radius: 16,
        blur: 14,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 17),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (previewText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    previewText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 9),
                ] else
                  const SizedBox(height: 6),
                Text(
                  RelativeTimeFormatter.formatUpdatedAt(
                    updatedAt: note.updatedAt,
                    now: DateTime.now(),
                    l10n: l10n,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
