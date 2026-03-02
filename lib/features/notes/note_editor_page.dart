import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/models/app_services.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/ios_group_section.dart';

/// 笔记编辑页。
///
/// 支持创建、编辑、保存与软删除。
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, this.noteId});

  final String? noteId;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  int? _expectedHeadRevision;
  String? _activeNoteId;

  @override
  void initState() {
    super.initState();
    _activeNoteId = widget.noteId;
    _load();
  }

  /// 根据 noteId 加载已有笔记内容。
  Future<void> _load() async {
    if (_activeNoteId == null) {
      setState(() => _loading = false);
      return;
    }

    final services = ref.read(appServicesProvider);
    final note = await services.noteRepository.getByNoteId(_activeNoteId!);
    if (note != null) {
      _titleController.text = note.title;
      _contentController.text = note.contentMd;
      _expectedHeadRevision = note.headRevision;
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 顶部标题根据是否已有 noteId 区分“新建/编辑”。
    final title = _activeNoteId == null ? l10n.newNote : l10n.editNote;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // 编辑已有笔记时显示删除按钮。
          if (_activeNoteId != null)
            IconButton(
              onPressed: _saving ? null : _deleteNote,
              icon: const Icon(CupertinoIcons.trash),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        // 编辑页背景渐变。
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
          ),
        ),
        child:
            _loading
                // 首次载入旧笔记时的加载态。
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      children: [
                        // 标题输入区。
                        IosGroupSection(
                          title: l10n.titleHint,
                          child: TextField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              hintText: l10n.titleHint,
                            ),
                          ),
                        ),
                        Expanded(
                          child: IosGroupSection(
                            // 正文输入区，占满中间可用高度。
                            title: l10n.tabNotes,
                            expandBody: true,
                            bottomSpacing: 8,
                            child: TextField(
                              controller: _contentController,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: InputDecoration(
                                hintText: l10n.markdownHint,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // 底部保存按钮。
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon:
                                _saving
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Icon(
                                      CupertinoIcons.check_mark_circled,
                                    ),
                            label: Text(_saving ? l10n.saving : l10n.save),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  /// 保存当前编辑内容，并在冲突时提示已创建副本。
  Future<void> _save() async {
    setState(() => _saving = true);
    final services = ref.read(appServicesProvider);
    try {
      final result = await services.syncEngine.saveLocalNote(
        noteId: _activeNoteId,
        title: _titleController.text,
        contentMd: _contentController.text,
        expectedHeadRevision: _expectedHeadRevision,
      );
      _activeNoteId = result.note.noteId;
      _expectedHeadRevision = result.note.headRevision;
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.createdConflictCopy
                ? context.l10n.conflictCopyCreated
                : context.l10n.saved,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.saveFailedWithReason(e.toString())),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// 软删除当前笔记。
  Future<void> _deleteNote() async {
    final id = _activeNoteId;
    if (id == null) {
      return;
    }

    setState(() => _saving = true);
    final services = ref.read(appServicesProvider);
    try {
      await services.syncEngine.deleteLocalNote(id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.deleteFailedWithReason(e.toString())),
        ),
      );
      setState(() => _saving = false);
    }
  }
}
