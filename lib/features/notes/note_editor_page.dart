import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
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
import 'editor/note_editor_extensions.dart';
import 'editor/note_editor_mobile_toolbar.dart';

/// 笔记编辑页（AppFlowy 版本）。
///
/// 设计原则：
/// - 页面仅承担 UI 与交互编排；
/// - 读写与会话生命周期交由 [NoteEditorController]；
/// - 页面保持单一编辑模式，避免无用的视图切换状态。
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, this.noteId});

  final String? noteId;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage>
    with WidgetsBindingObserver {
  /// 删除后支持撤销的有效时长（对应 SnackBar duration）。
  static const Duration _deleteUndoDuration = Duration(seconds: 4);
  static const double _bottomStatusBarHeight = 24;
  static const double _mobileToolbarHeight = 44;

  /// 编辑页会话控制器，负责加载/保存/删除等业务操作。
  late final NoteEditorController _controller;

  /// 编辑器快捷键集合（在默认快捷键基础上插入 Markdown 感知粘贴）。
  late final List<CommandShortcutEvent> _commandShortcutEvents;

  /// 防止重复触发返回逻辑（例如系统返回与按钮返回同时触发）。
  bool _isClosing = false;

  /// 用户连续滚动期间仅清理一次折叠光标，避免频繁触发选区变更造成闪烁。
  bool _selectionClearedByUserScroll = false;

  bool get _isMobileRuntime {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 通过 Provider 读取全局服务并创建编辑会话控制器。
    _controller = NoteEditorController(
      services: ref.read(appServicesProvider),
      initialNoteId: widget.noteId,
    );
    _commandShortcutEvents = buildNodeJotCommandShortcutEvents(
      onMarkdownAwarePaste: _handleMarkdownAwarePaste,
    );
    // 异步初始化：加载已有笔记或创建新笔记初始文档。
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // 应用切后台/退出前，尽力强制保存一次，降低最后输入丢失风险。
      unawaited(_saveBeforeAppBackground());
    }
  }

  Future<void> _saveBeforeAppBackground() async {
    if (!mounted || _isClosing || _controller.loadingNotifier.value) {
      return;
    }
    await _controller.saveOnAppLifecycleExit();
  }

  /// 统一处理返回动作。
  ///
  /// 返回前会触发一次“离开编辑器”流程：
  /// - 新建笔记：有内容则保存；被清空则不保存（已落库则自动删除）；
  /// - 已有笔记：若被清空，先二次确认再删除。
  Future<void> _handleBack() async {
    if (_isClosing) {
      return;
    }
    _isClosing = true;
    try {
      final l10n = context.l10n;
      final contentEmpty = _controller.isCurrentDocumentEmpty();
      if (contentEmpty && _controller.isEditingExistingNote) {
        final confirmedDelete = await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: Text(l10n.deleteNoteTitle),
                content: Text(l10n.clearContentWillDeleteConfirmMessage),
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
        if (confirmedDelete != true) {
          return;
        }
        await _controller.deleteCurrentNote();
      } else {
        await _controller.onLeavingEditor();
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      _isClosing = false;
    }
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
    if (!mounted) {
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

      // 选择路径在移动端可能指向行内节点，不能直接用于“插入块”。
      // 这里统一转换为顶层块路径：在当前块后插入。
      final blockCount = editorState.document.root.children.length;
      final currentBlockIndex =
          selection.end.path.isEmpty ? 0 : selection.end.path.first;
      final clampedBlockIndex =
          currentBlockIndex < 0
              ? 0
              : (currentBlockIndex >= blockCount
                  ? (blockCount == 0 ? 0 : blockCount - 1)
                  : currentBlockIndex);
      final insertBlockIndex = blockCount == 0 ? 0 : clampedBlockIndex + 1;

      final transaction = editorState.transaction;
      transaction.insertNodes([insertBlockIndex], nodes);
      transaction.afterSelection = Selection.single(
        path: [insertBlockIndex],
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

  /// 处理编辑器滚动通知。
  ///
  /// AppFlowy 在选区变化后会自动尝试把光标滚动到可见区域；
  /// 当长文档滚动时若当前光标在顶部，可能触发视图被“回拉”。
  /// 这里在用户主动滚动时清理折叠光标（不影响文本选区），
  /// 用于避免阅读场景下的自动回跳。
  bool _handleEditorUserScroll(UserScrollNotification notification) {
    final state = _controller.editorState;
    if (state == null) {
      return false;
    }

    // 键盘弹起时保持选区，避免干扰输入与键盘工具栏状态。
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return false;
    }

    if (notification.direction == ScrollDirection.idle) {
      _selectionClearedByUserScroll = false;
      return false;
    }

    if (_selectionClearedByUserScroll) {
      return false;
    }

    final selection = state.selection;
    if (selection == null || !selection.isCollapsed) {
      return false;
    }

    state.selection = null;
    _selectionClearedByUserScroll = true;
    return false;
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final l10n = context.l10n;
    return AppBar(
      title: Text(
        l10n.noteTitle,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: _handleBack,
        icon: const Icon(CupertinoIcons.chevron_back),
      ),
      actions: [
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

    final editorStyle = _buildEditorStyle(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardInset > 0;
    _controller.setKeyboardVisible(keyboardVisible);
    final bottomPadding =
        keyboardVisible
            // MobileToolbarV2 会处理工具栏自身占位，这里仅补键盘抬升高度，
            // 避免工具栏高度在两层重复叠加导致底部出现空白带。
            ? keyboardInset + AppSpacing.s
            : _bottomStatusBarHeight +
                MediaQuery.paddingOf(context).bottom +
                AppSpacing.l;

    Widget editor = AppFlowyEditor(
      editorState: state,
      // 仅新建笔记自动聚焦；已有长笔记默认不抢光标，减少滚动回跳。
      autoFocus: widget.noteId == null,
      editorStyle: editorStyle,
      commandShortcutEvents: _commandShortcutEvents,
      characterShortcutEvents: buildNodeJotCharacterShortcutEvents(
        brightness: Theme.of(context).brightness,
      ),
      shrinkWrap: false,
    );

    if (_isMobileRuntime) {
      final toolbarBackground =
          isDark
              ? AppColors.surfaceDark.withValues(alpha: 0.96)
              : AppColors.surface.withValues(alpha: 0.96);
      final toolbarForeground =
          isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
      final toolbarIcon =
          isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
      final toolbarHighlight =
          isDark ? AppColors.accent : AppColors.navActiveText;
      final toolbarOutline =
          isDark ? AppColors.borderSoftDark : AppColors.borderSoft;
      final tabSelectedBackground = toolbarHighlight.withValues(
        alpha: isDark ? 0.26 : 0.14,
      );
      final tabSelectedForeground =
          isDark ? AppColors.textPrimaryDark : AppColors.navActiveLabel;
      editor = MobileToolbarV2(
        editorState: state,
        toolbarItems: buildNodeJotMobileToolbarItems(context),
        backgroundColor: toolbarBackground,
        foregroundColor: toolbarForeground,
        iconColor: toolbarIcon,
        itemHighlightColor: toolbarHighlight,
        itemOutlineColor: toolbarOutline,
        outlineColor: toolbarOutline,
        primaryColor: toolbarHighlight,
        onPrimaryColor: isDark ? AppColors.textPrimaryDark : AppColors.surface,
        tabBarSelectedBackgroundColor: tabSelectedBackground,
        tabBarSelectedForegroundColor: tabSelectedForeground,
        toolbarHeight: _mobileToolbarHeight,
        child: editor,
      );
    }

    // 单一编辑态：渲染 AppFlowyEditor，并套用 NodeJot 主题样式。
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.s,
        AppSpacing.l,
        bottomPadding,
      ),
      child: NotificationListener<UserScrollNotification>(
        onNotification: _handleEditorUserScroll,
        child: editor,
      ),
    );
  }

  /// 底部悬浮状态条：
  /// - 始终覆盖在滚动内容上方；
  /// - 右侧仅展示小字号字数统计；
  /// - 不参与点击事件，避免挡住编辑区手势。
  Widget _buildBottomStatusBar(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.9)
            : AppColors.surface.withValues(alpha: 0.9);
    final borderColor =
        isDark ? AppColors.borderSoftDark : AppColors.borderSoft;
    final textColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: _bottomStatusBarHeight + safeBottom,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.l,
            4,
            AppSpacing.l,
            4 + safeBottom,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(top: BorderSide(color: borderColor, width: 0.8)),
          ),
          child: Row(
            children: [
              const Spacer(),
              ValueListenableBuilder<int>(
                valueListenable: _controller.charCountNotifier,
                builder: (context, count, _) {
                  return Text(
                    l10n.charCountLabel(count),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
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
    return PopScope<void>(
      // 自定义返回流程，确保先执行保存/清理，再 pop 页面。
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_handleBack());
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
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

                final keyboardVisible =
                    MediaQuery.viewInsetsOf(context).bottom > 0;

                return Stack(
                  children: [
                    // 主体编辑区域。
                    Positioned.fill(child: _buildEditorContent(context)),
                    if (!keyboardVisible) _buildBottomStatusBar(context),
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
