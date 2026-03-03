import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/app_services.dart';
import '../../l10n/app_localizations.dart';
import 'editor/note_editor_controller.dart';
import 'editor/widgets/note_editor_preview.dart';
import 'editor/widgets/note_editor_status_badge.dart';

/// 笔记编辑页（AppFlowy 版本）。
///
/// 设计原则：
/// - 页面仅承担 UI 与交互编排；
/// - 读写与会话生命周期交由 [NoteEditorController]；
/// - 编辑/预览切换用 `IndexedStack`，以保留双方滚动状态。
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, this.noteId});

  final String? noteId;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  static const Duration _savedHintDuration = Duration(seconds: 3);
  static const Duration _deleteUndoDuration = Duration(seconds: 4);

  late final NoteEditorController _controller;
  final ScrollController _previewScrollController = ScrollController();
  bool _previewMode = false;
  bool _showSavedHint = false;
  bool _isClosing = false;
  Timer? _savedHintTimer;

  @override
  void initState() {
    super.initState();
    _controller = NoteEditorController(
      services: ref.read(appServicesProvider),
      initialNoteId: widget.noteId,
    );
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _savedHintTimer?.cancel();
    _previewScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    if (_isClosing) {
      return;
    }
    _isClosing = true;
    await _controller.onLeavingEditor();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _handleManualSave() async {
    await _controller.saveNow();
    if (!mounted) {
      return;
    }
    _savedHintTimer?.cancel();
    setState(() {
      _showSavedHint = true;
    });
    _savedHintTimer = Timer(_savedHintDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showSavedHint = false;
      });
    });
  }

  Future<void> _handleDelete() async {
    final l10n = context.l10n;
    final deletedText = l10n.selectedDeleted(1);
    final undoText = l10n.undo;
    final noteId = _controller.currentNoteId;
    if (noteId == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(l10n.deleteNoteTitle),
            content: Text(l10n.deleteNoteConfirmMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    await _controller.deleteCurrentNote();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        duration: _deleteUndoDuration,
        content: Text(deletedText),
        action: SnackBarAction(
          label: undoText,
          onPressed: () {
            unawaited(_controller.restoreDeletedCurrentNote());
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final l10n = context.l10n;
    final iconColor = Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: 0.82);
    return AppBar(
      title: Text(l10n.editNote),
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: _handleBack,
        icon: const Icon(CupertinoIcons.chevron_back),
      ),
      actions: [
        IconButton(
          tooltip: _previewMode ? l10n.editorMode : l10n.previewMode,
          onPressed: () {
            setState(() {
              _previewMode = !_previewMode;
            });
          },
          icon: Icon(
            _previewMode ? CupertinoIcons.pencil : CupertinoIcons.eye,
            color: iconColor,
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _controller.savingNotifier,
          builder: (context, saving, _) {
            return IconButton(
              tooltip: l10n.save,
              onPressed: saving ? null : _handleManualSave,
              icon:
                  saving
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.0),
                      )
                      : Icon(Icons.save_outlined, color: iconColor),
            );
          },
        ),
        IconButton(
          tooltip: l10n.delete,
          onPressed: _handleDelete,
          icon: Icon(
            CupertinoIcons.delete,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildEditorContent(BuildContext context) {
    final state = _controller.editorState;
    if (state == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_previewMode) {
      return NoteEditorPreview(
        markdownListenable: _controller.markdownNotifier,
        scrollController: _previewScrollController,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final editorStyle = EditorStyle.mobile(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      cursorColor:
          isDark ? AppColors.textPrimaryDark : const Color(0xFF00BCF0),
      selectionColor:
          isDark
              ? const Color.fromARGB(80, 122, 162, 255)
              : const Color.fromARGB(53, 111, 201, 231),
      textStyleConfiguration: TextStyleConfiguration(
        text: TextStyle(
          fontSize: 16,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.s,
        AppSpacing.l,
        AppSpacing.m,
      ),
      child: AppFlowyEditor(
        editorState: state,
        autoFocus: true,
        editorStyle: editorStyle,
        shrinkWrap: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_handleBack());
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.pageBackground(Theme.of(context).brightness),
          ),
          child: SafeArea(
            child: ValueListenableBuilder<bool>(
              valueListenable: _controller.loadingNotifier,
              builder: (context, loading, _) {
                if (loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Stack(
                  children: [
                    Positioned.fill(child: _buildEditorContent(context)),
                    Positioned(
                      right: AppSpacing.l,
                      bottom:
                          AppSpacing.l + MediaQuery.paddingOf(context).bottom,
                      child: ValueListenableBuilder<int>(
                        valueListenable: _controller.charCountNotifier,
                        builder: (context, count, _) {
                          return NoteEditorStatusBadge(
                            savedLabel: l10n.saved,
                            countLabel: l10n.charCountLabel(count),
                            showSavedHint: _showSavedHint,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
