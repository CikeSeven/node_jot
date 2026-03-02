import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/models/app_services.dart';
import '../../data/isar/collections/note_entity.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/ios_frosted_panel.dart';
import '../conflicts/conflicts_page.dart';
import 'note_editor_page.dart';

/// 笔记首页。
///
/// 展示活动笔记列表、冲突入口和新建按钮。
class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final services = ref.watch(appServicesProvider);
    // 预留 FAB 与悬浮底栏的安全间距，避免被遮挡。
    final fabBottomOffset = 84 + MediaQuery.paddingOf(context).bottom;
    // 预留列表底部安全间距，避免最后一项被悬浮底栏遮挡。
    final listBottomOffset = 112 + MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      // 右下角新建按钮（上移以避开底栏）。
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: fabBottomOffset),
        child: FloatingActionButton(
          onPressed: () => _openEditor(context),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      body: Container(
        // 页面主背景：顶部到底部的浅色渐变。
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部标题与冲突入口。
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.m,
                  AppSpacing.l,
                  0
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'NodeJot',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IosFrostedPanel(
                      padding: const EdgeInsets.all(6),
                      radius: 14,
                      blur: 14,
                      child: IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ConflictsPage(),
                            ),
                          );
                        },
                        icon: const Icon(
                          CupertinoIcons.exclamationmark_bubble,
                          size: 24,
                        ),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        tooltip: l10n.conflicts,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              // 主内容区：标题行作为列表第一个条目，随列表一起滚动。
              Expanded(
                child: StreamBuilder<List<NoteEntity>>(
                  stream: services.noteRepository.watchActiveNotes(),
                  builder: (context, snapshot) {
                    final notes = snapshot.data ?? const <NoteEntity>[];
                    return ListView.separated(
                      key: const PageStorageKey<String>('notes_list'),
                      padding: EdgeInsets.only(bottom: listBottomOffset),
                      itemCount: notes.isEmpty ? 2 : notes.length + 1,
                      separatorBuilder: (context, index) {
                        // 标题行与内容间距更小，列表项间距保持原样。
                        return SizedBox(height: index == 0 ? 8 : 10);
                      },
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.l,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n.tabNotes,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM d').format(DateTime.now()),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          );
                        }

                        if (notes.isEmpty) {
                          // 空态：提示并引导创建第一条笔记。
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.l,
                            ),
                            child: _EmptyState(
                              onCreate: () => _openEditor(context),
                            ),
                          );
                        }

                        final note = notes[index - 1];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.l,
                          ),
                          child: _NoteCard(
                            note: note,
                            onTap: () => _openEditor(context, note.noteId),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 打开编辑页；未传 noteId 时创建新笔记。
  void _openEditor(BuildContext context, [String? noteId]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteEditorPage(noteId: noteId)),
    );
  }
}

/// 笔记列表卡片。
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap});

  final NoteEntity note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    return IosFrostedPanel(
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
              // 笔记标题。
              Text(
                note.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: 17),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // 内容摘要（最多显示 3 行）。
              Text(
                note.contentMd,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 9),
              // 底部元信息：更新时间 + 冲突标记。
              Row(
                children: [
                  Text(
                    formatter.format(note.updatedAt.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (note.isConflictCopy)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3D9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.noteConflictTag,
                        style: const TextStyle(
                          color: Color(0xFFB54708),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 空状态视图。
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 空态图标。
          const Icon(
            CupertinoIcons.square_pencil,
            size: 38,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          // 空态文案。
          Text(l10n.noNotesYet),
          const SizedBox(height: 12),
          // 主动操作：创建笔记。
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(CupertinoIcons.add),
            label: Text(l10n.createNote),
          ),
        ],
      ),
    );
  }
}
