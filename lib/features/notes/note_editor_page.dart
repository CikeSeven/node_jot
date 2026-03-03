import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/app_services.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/note_doc_codec.dart';
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
  /// “已保存”提示的停留时长。
  static const Duration _savedHintDuration = Duration(seconds: 3);

  /// 删除后支持撤销的有效时长（对应 SnackBar duration）。
  static const Duration _deleteUndoDuration = Duration(seconds: 4);

  /// 编辑页会话控制器，负责加载/保存/删除等业务操作。
  late final NoteEditorController _controller;

  /// 编辑器快捷键集合（在默认快捷键基础上插入 Markdown 感知粘贴）。
  late final List<CommandShortcutEvent> _commandShortcutEvents;

  /// 预览模式专用滚动控制器。
  ///
  /// 使用独立控制器可在“编辑/预览”切换时保留预览滚动位置。
  final ScrollController _previewScrollController = ScrollController();

  /// 当前是否为预览模式（`false` = 编辑，`true` = 预览）。
  bool _previewMode = false;

  /// 右下角状态卡片是否显示“已保存”文案。
  bool _showSavedHint = false;

  /// 防止重复触发返回逻辑（例如系统返回与按钮返回同时触发）。
  bool _isClosing = false;

  /// 控制“已保存”提示自动收起的计时器。
  Timer? _savedHintTimer;

  @override
  void initState() {
    super.initState();
    // 通过 Provider 读取全局服务并创建编辑会话控制器。
    _controller = NoteEditorController(
      services: ref.read(appServicesProvider),
      initialNoteId: widget.noteId,
    );
    _commandShortcutEvents = _buildCommandShortcutEvents();
    // 异步初始化：加载已有笔记或创建新笔记初始文档。
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    // 释放页面层资源，防止计时器与滚动控制器泄漏。
    _savedHintTimer?.cancel();
    _previewScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// 统一处理返回动作。
  ///
  /// 返回前会触发一次“离开编辑器”流程：
  /// - 尝试保存最后编辑结果；
  /// - 若是本次新建且最终为空草稿，自动删除。
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
    // 手动保存后短暂展示“已保存”反馈，不打断编辑流程。
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
    // 新建未落库场景：无 noteId 时直接关闭页面。
    final noteId = _controller.currentNoteId;
    if (noteId == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    // 二次确认，避免误删。
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

    // 删除成功后立刻退出编辑页，并提供撤销入口。
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

  /// 组装编辑器命令快捷键。
  ///
  /// 处理策略：
  /// - 先拦截 `Ctrl+V / Cmd+V`；
  /// - 若剪贴板文本看起来像 Markdown，则转为结构化节点插入；
  /// - 否则回退 AppFlowy 默认 `pasteCommand`。
  List<CommandShortcutEvent> _buildCommandShortcutEvents() {
    return [
      CommandShortcutEvent(
        key: 'nodejot_markdown_paste',
        command: 'ctrl+v',
        macOSCommand: 'cmd+v',
        getDescription: () => 'NodeJot Markdown-aware paste',
        handler: (editorState) {
          // CommandShortcutEvent 的 handler 为同步回调，
          // 粘贴板读取是异步操作，因此在此启动异步任务并标记事件已处理。
          unawaited(_handleMarkdownAwarePaste(editorState));
          return KeyEventResult.handled;
        },
      ),
      ...standardCommandShortcutEvents,
    ];
  }

  /// 处理 Markdown 感知粘贴。
  ///
  /// 说明：
  /// - 若剪贴板为空、非 markdown 或解析失败，回退默认粘贴；
  /// - 若解析成功，则将 markdown 转换后的块节点插入当前光标路径。
  Future<void> _handleMarkdownAwarePaste(EditorState editorState) async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final rawText = clipboardData?.text;
      final text = rawText?.trim();
      if (text == null || text.isEmpty) {
        pasteCommand.execute(editorState);
        return;
      }

      if (!NoteDocCodec.isLikelyMarkdownSource(text)) {
        pasteCommand.execute(editorState);
        return;
      }

      final selection = editorState.selection;
      if (selection == null || selection.end.path.isEmpty) {
        pasteCommand.execute(editorState);
        return;
      }

      final document = markdownToDocument(text);
      final nodes =
          document.root.children.map((node) => node.copyWith()).toList();
      if (nodes.isEmpty) {
        pasteCommand.execute(editorState);
        return;
      }

      final transaction = editorState.transaction;
      transaction.insertNodes(selection.end.path, nodes);
      transaction.afterSelection = Selection.single(
        path: selection.end.path,
        startOffset: 0,
      );
      await editorState.apply(transaction);
    } catch (e) {
      AppLog.e(
        'note-editor',
        'markdown paste failed, fallback to plain paste: $e',
      );
      pasteCommand.execute(editorState);
    }
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
        // 编辑/预览切换按钮：
        // 使用同一份文档状态，通过 UI 视图切换来保留上下文。
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
        // 手动保存按钮：
        // 保存中显示小转圈，避免重复点击触发并发保存。
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
        // 删除按钮（危险操作，使用 error 语义色）。
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
      // 初始化期间 editorState 为空，展示加载占位。
      return const Center(child: CircularProgressIndicator());
    }

    if (_previewMode) {
      // 预览态：读取控制器中的 markdown 快照并可滚动查看。
      return NoteEditorPreview(
        markdownListenable: _controller.markdownNotifier,
        scrollController: _previewScrollController,
      );
    }

    final editorStyle = _buildEditorStyle(context);

    // 编辑态：渲染 AppFlowyEditor，并套用 NodeJot 主题样式。
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
        commandShortcutEvents: _commandShortcutEvents,
        shrinkWrap: false,
      ),
    );
  }

  /// 构建与 NodeJot 主题一致的 AppFlowy 编辑器配色。
  ///
  /// 包含正文、链接、代码样式、自动补全、光标、选区与拖拽手柄，
  /// 确保亮暗模式下都有足够对比度。
  EditorStyle _buildEditorStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final primaryColor = isDark ? const Color(0xFFBCA8FF) : AppColors.primary;
    final linkColor =
        isDark ? const Color(0xFFCDBBFF) : AppColors.navActiveText;
    final codeBg =
        isDark
            ? AppColors.surfaceSoftDark.withValues(alpha: 0.72)
            : AppColors.primarySoft.withValues(alpha: 0.82);

    return EditorStyle.mobile(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      cursorColor: primaryColor,
      dragHandleColor: primaryColor,
      selectionColor: primaryColor.withValues(alpha: isDark ? 0.34 : 0.22),
      textStyleConfiguration: TextStyleConfiguration(
        text: TextStyle(fontSize: 16, height: 1.58, color: textColor),
        href: TextStyle(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor.withValues(alpha: 0.8),
        ),
        code: TextStyle(
          color: isDark ? const Color(0xFFD9CCFF) : const Color(0xFF6D37D2),
          backgroundColor: codeBg,
          fontFamily: 'monospace',
        ),
        autoComplete: TextStyle(color: secondaryColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope<void>(
      // 自定义返回流程，确保先执行保存/清理，再 pop 页面。
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
                  // 初始加载阶段统一展示全屏 loading。
                  return const Center(child: CircularProgressIndicator());
                }

                return Stack(
                  children: [
                    // 主体编辑区域（编辑器或预览）。
                    Positioned.fill(child: _buildEditorContent(context)),
                    // 右下角悬浮状态卡片（字数/已保存）。
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
