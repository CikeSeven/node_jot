import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/app_services.dart';
import '../../../core/utils/note_category_codec.dart';
import '../../../l10n/app_localizations.dart';
import '../editor/note_editor_controller.dart';
import '../sections/note_editor_app_bar_section.dart';
import '../sections/note_editor_content_section.dart';
import '../sections/note_editor_status_bar_section.dart';

/// 笔记编辑页（Quill 版本）。
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
  static const double _mobileToolbarFloatingGap = 8;
  static const double _mobileToolbarHorizontalInset = 12;
  static const double _desktopToolbarTopGap = 8;

  /// 编辑页会话控制器，负责加载/保存/删除等业务操作。
  late final NoteEditorController _controller;

  /// 防止重复触发返回逻辑（例如系统返回与按钮返回同时触发）。
  bool _isClosing = false;

  /// 用户连续滚动期间仅执行一次失焦，避免频繁触发焦点抖动。
  bool _focusClearedByUserScroll = false;

  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();

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
    _controller = NoteEditorController(
      services: ref.read(appServicesProvider),
      initialNoteId: widget.noteId,
    );
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
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
    if (!mounted) {
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

  Future<void> _handleManageCategories() async {
    if (_controller.loadingNotifier.value) {
      return;
    }
    final catalog =
        await _controller.services.noteRepository.loadCategoryCatalog();
    if (!mounted) {
      return;
    }
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return _CategoryPickerSheet(
          initialCatalog: catalog,
          initialSelected: _controller.selectedCategories,
        );
      },
    );
    if (result == null) {
      return;
    }
    _controller.updateSelectedCategories(result);
  }

  /// 处理编辑器滚动通知。
  ///
  /// 键盘关闭时，用户主动滚动视图会让编辑器失焦，避免误触导致反复抢焦点。
  bool _handleEditorUserScroll(UserScrollNotification notification) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return false;
    }

    if (notification.direction == ScrollDirection.idle) {
      _focusClearedByUserScroll = false;
      return false;
    }

    if (_focusClearedByUserScroll) {
      return false;
    }

    _editorFocusNode.unfocus();
    _focusClearedByUserScroll = true;
    return false;
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return NoteEditorAppBarSection(
      onBack: _handleBack,
      onManageCategories: _handleManageCategories,
      onDelete: _handleDelete,
    );
  }

  Widget _buildEditorContent(
    BuildContext context, {
    required bool showFloatingToolbar,
    required bool showDesktopPinnedToolbar,
  }) {
    final quillController = _controller.quillController;
    if (quillController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final bottomPadding =
        showFloatingToolbar
            ? _mobileToolbarHeight + _mobileToolbarFloatingGap
            : _bottomStatusBarHeight + MediaQuery.paddingOf(context).bottom;
    final topPadding =
        showDesktopPinnedToolbar
            ? _mobileToolbarHeight + _desktopToolbarTopGap
            : 0.0;

    final editor = quill.QuillEditor(
      focusNode: _editorFocusNode,
      scrollController: _editorScrollController,
      controller: quillController,
      config: quill.QuillEditorConfig(
        autoFocus: widget.noteId == null,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        placeholder: context.l10n.editorMode,
        customStyles: _buildEditorStyle(context),
      ),
    );

    return NoteEditorContentSection(
      topPadding: topPadding,
      bottomPadding: bottomPadding,
      onUserScroll: _handleEditorUserScroll,
      child: editor,
    );
  }

  Widget _buildKeyboardFloatingToolbar(
    BuildContext context,
    quill.QuillController controller,
  ) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      left: _mobileToolbarHorizontalInset,
      right: _mobileToolbarHorizontalInset,
      // Scaffold 已处理键盘避让，这里固定贴底悬浮。
      bottom: 0,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: _mobileToolbarFloatingGap),
        child: Material(
          color: Colors.transparent,
          child: _buildMobileToolbar(context, controller),
        ),
      ),
    );
  }

  Widget _buildDesktopPinnedToolbar(
    BuildContext context,
    quill.QuillController controller,
  ) {
    return Positioned(
      left: AppSpacing.l,
      right: AppSpacing.l,
      top: 0,
      child: Material(
        color: Colors.transparent,
        child: _buildMobileToolbar(context, controller),
      ),
    );
  }

  Widget _buildMobileToolbar(
    BuildContext context,
    quill.QuillController controller,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final toolbarBackground =
        isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.96)
            : AppColors.surface.withValues(alpha: 0.96);
    final toolbarIcon =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final toolbarSelected = isDark ? AppColors.accent : AppColors.navActiveText;
    final toolbarOutline =
        isDark ? AppColors.borderSoftDark : AppColors.borderSoft;

    return Container(
      height: _mobileToolbarHeight,
      decoration: BoxDecoration(
        color: toolbarBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: toolbarOutline),
      ),
      child: quill.QuillSimpleToolbar(
        controller: controller,
        config: quill.QuillSimpleToolbarConfig(
          toolbarSize: 18,
          multiRowsDisplay: false,
          showDividers: true,
          showFontFamily: false,
          showFontSize: false,
          showBoldButton: true,
          showItalicButton: true,
          showUnderLineButton: true,
          showStrikeThrough: true,
          showInlineCode: true,
          showSmallButton: false,
          showColorButton: true,
          showBackgroundColorButton: true,
          showClearFormat: true,
          showUndo: true,
          showRedo: true,
          showListNumbers: true,
          showListBullets: true,
          showListCheck: true,
          showCodeBlock: true,
          showQuote: true,
          showIndent: true,
          showLink: true,
          showAlignmentButtons: false,
          showHeaderStyle: false,
          showDirection: false,
          showSearchButton: false,
          showSubscript: false,
          showSuperscript: false,
          customButtons: [
            quill.QuillToolbarCustomButtonOptions(
              icon: const Icon(Icons.title, size: 18),
              tooltip: 'Heading',
              onPressed: () => _cycleHeaderStyle(controller),
            ),
          ],
          iconTheme: quill.QuillIconTheme(
            iconButtonUnselectedData: quill.IconButtonData(color: toolbarIcon),
            iconButtonSelectedData: quill.IconButtonData(
              color: toolbarSelected,
              style: IconButton.styleFrom(
                backgroundColor: toolbarSelected.withValues(alpha: 0.14),
              ),
            ),
          ),
          decoration: const BoxDecoration(color: Colors.transparent),
          color: Colors.transparent,
        ),
      ),
    );
  }

  void _cycleHeaderStyle(quill.QuillController controller) {
    final currentHeader =
        controller.getSelectionStyle().attributes[quill.Attribute.header.key];
    final nextHeader = switch (currentHeader?.value) {
      1 => quill.Attribute.h2,
      2 => quill.Attribute.h3,
      3 => quill.Attribute.header,
      _ => quill.Attribute.h1,
    };
    controller.formatSelection(nextHeader);
  }

  /// 底部悬浮状态条区块。
  Widget _buildBottomStatusBar() {
    return NoteEditorStatusBarSection(
      charCountListenable: _controller.charCountNotifier,
      height: _bottomStatusBarHeight,
    );
  }

  /// 构建与 NodeJot 主题一致的 Quill 编辑器样式。
  quill.DefaultStyles _buildEditorStyle(BuildContext context) {
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

    return quill.DefaultStyles(
      paragraph: quill.DefaultTextBlockStyle(
        TextStyle(fontSize: 16, height: 1.58, color: textColor),
        quill.HorizontalSpacing.zero,
        quill.VerticalSpacing.zero,
        quill.VerticalSpacing.zero,
        null,
      ),
      h1: quill.DefaultTextBlockStyle(
        TextStyle(
          fontSize: 28,
          height: 1.28,
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
        quill.HorizontalSpacing.zero,
        const quill.VerticalSpacing(8, 6),
        quill.VerticalSpacing.zero,
        null,
      ),
      h2: quill.DefaultTextBlockStyle(
        TextStyle(
          fontSize: 22,
          height: 1.32,
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
        quill.HorizontalSpacing.zero,
        const quill.VerticalSpacing(8, 4),
        quill.VerticalSpacing.zero,
        null,
      ),
      placeHolder: quill.DefaultTextBlockStyle(
        TextStyle(
          fontSize: 16,
          height: 1.58,
          color: secondaryColor.withValues(alpha: 0.8),
        ),
        quill.HorizontalSpacing.zero,
        quill.VerticalSpacing.zero,
        quill.VerticalSpacing.zero,
        null,
      ),
      link: TextStyle(
        color: linkColor,
        decoration: TextDecoration.underline,
        decorationColor: linkColor.withValues(alpha: 0.8),
      ),
      inlineCode: quill.InlineCodeStyle(
        style: TextStyle(
          color: isDark ? const Color(0xFFD9CCFF) : const Color(0xFF6D37D2),
          fontFamily: 'monospace',
        ),
        backgroundColor: codeBg,
        radius: const Radius.circular(4),
      ),
      code: quill.DefaultTextBlockStyle(
        TextStyle(
          color: isDark ? const Color(0xFFD9CCFF) : const Color(0xFF6D37D2),
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.5,
        ),
        const quill.HorizontalSpacing(12, 12),
        const quill.VerticalSpacing(6, 6),
        quill.VerticalSpacing.zero,
        BoxDecoration(color: codeBg, borderRadius: BorderRadius.circular(8)),
      ),
      quote: quill.DefaultTextBlockStyle(
        TextStyle(fontSize: 16, height: 1.58, color: secondaryColor),
        const quill.HorizontalSpacing(12, 0),
        const quill.VerticalSpacing(6, 6),
        quill.VerticalSpacing.zero,
        BoxDecoration(
          border: Border(
            left: BorderSide(
              color: primaryColor.withValues(alpha: isDark ? 0.45 : 0.32),
              width: 3,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardInset > 0;

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
            top: false,
            child: ValueListenableBuilder<bool>(
              valueListenable: _controller.loadingNotifier,
              builder: (context, loading, _) {
                if (loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final quillController = _controller.quillController;
                final showFloatingToolbar =
                    _isMobileRuntime &&
                    keyboardVisible &&
                    quillController != null;
                final showDesktopPinnedToolbar =
                    !_isMobileRuntime && quillController != null;
                _controller.setKeyboardVisible(keyboardVisible);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: _buildEditorContent(
                        context,
                        showFloatingToolbar: showFloatingToolbar,
                        showDesktopPinnedToolbar: showDesktopPinnedToolbar,
                      ),
                    ),
                    if (showDesktopPinnedToolbar)
                      _buildDesktopPinnedToolbar(context, quillController),
                    if (!keyboardVisible) _buildBottomStatusBar(),
                    if (showFloatingToolbar)
                      _buildKeyboardFloatingToolbar(context, quillController),
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

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.initialCatalog,
    required this.initialSelected,
  });

  final List<String> initialCatalog;
  final List<String> initialSelected;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  late List<String> _catalog;
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = NoteCategoryCodec.normalizeList(widget.initialSelected);
    _catalog = _mergeCatalog(widget.initialCatalog, _selected);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  List<String> _mergeCatalog(List<String> catalog, List<String> selected) {
    final normalizedCatalog = NoteCategoryCodec.normalizeList(catalog);
    final normalizedSelected = NoteCategoryCodec.normalizeList(selected);
    final seen = <String>{};
    final merged = <String>[];

    for (final category in <String>[
      ...normalizedCatalog,
      ...normalizedSelected,
    ]) {
      final key = NoteCategoryCodec.toKey(category);
      if (key.isEmpty || !seen.add(key)) {
        continue;
      }
      merged.add(category);
    }
    merged.sort(
      (a, b) =>
          NoteCategoryCodec.toKey(a).compareTo(NoteCategoryCodec.toKey(b)),
    );
    return merged;
  }

  void _toggleCategory(String category, bool selected) {
    final key = NoteCategoryCodec.toKey(category);
    if (key.isEmpty) {
      return;
    }
    setState(() {
      if (selected) {
        if (_selected.any((item) => NoteCategoryCodec.toKey(item) == key)) {
          return;
        }
        _selected = <String>[
          ..._selected,
          NoteCategoryCodec.normalizeLabel(category),
        ];
      } else {
        _selected = _selected
            .where((item) => NoteCategoryCodec.toKey(item) != key)
            .toList(growable: false);
      }
      _selected = NoteCategoryCodec.normalizeList(_selected);
    });
  }

  void _addCategoryFromInput() {
    final value = NoteCategoryCodec.normalizeLabel(_inputController.text);
    if (value.isEmpty) {
      return;
    }
    final key = NoteCategoryCodec.toKey(value);
    _inputController.clear();
    setState(() {
      if (!_catalog.any((item) => NoteCategoryCodec.toKey(item) == key)) {
        _catalog = _mergeCatalog(<String>[..._catalog, value], _selected);
      }
      if (!_selected.any((item) => NoteCategoryCodec.toKey(item) == key)) {
        _selected = NoteCategoryCodec.normalizeList(<String>[
          ..._selected,
          value,
        ]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.m + bottomInset,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.categoryManageTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s),
            if (_selected.isNotEmpty) ...[
              Wrap(
                spacing: AppSpacing.s,
                runSpacing: AppSpacing.s,
                children: _selected
                    .map(
                      (category) => InputChip(
                        label: Text('# $category'),
                        onDeleted: () => _toggleCategory(category, false),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: AppSpacing.s),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addCategoryFromInput(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.categoryInputHint,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                FilledButton.tonal(
                  onPressed: _addCategoryFromInput,
                  child: Text(l10n.addCategory),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Flexible(
              child:
                  _catalog.isEmpty
                      ? Center(
                        child: Text(
                          l10n.categoryNoData,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                      : SingleChildScrollView(
                        child: Wrap(
                          spacing: AppSpacing.s,
                          runSpacing: AppSpacing.s,
                          children: _catalog
                              .map((category) {
                                final selected = _selected.any(
                                  (item) =>
                                      NoteCategoryCodec.toKey(item) ==
                                      NoteCategoryCodec.toKey(category),
                                );
                                return FilterChip(
                                  label: Text(category),
                                  selected: selected,
                                  onSelected:
                                      (value) =>
                                          _toggleCategory(category, value),
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
            ),
            const SizedBox(height: AppSpacing.m),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: AppSpacing.s),
                FilledButton(
                  onPressed:
                      () => Navigator.of(
                        context,
                      ).pop(NoteCategoryCodec.normalizeList(_selected)),
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
