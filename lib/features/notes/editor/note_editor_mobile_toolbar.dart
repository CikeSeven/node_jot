import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// 构建 NodeJot 手机端键盘悬浮工具栏项。
///
/// 说明：
/// - 复用 AppFlowy 内置常用项（不包含代码块）；
/// - 增加一个 NodeJot 自定义“模板节点”菜单，用于一键插入常用内容结构。
List<MobileToolbarItem> buildNodeJotMobileToolbarItems(BuildContext context) {
  return [
    blocksMobileToolbarItem,
    textDecorationMobileToolbarItem,
    linkMobileToolbarItem,
    todoListMobileToolbarItem,
    dividerMobileToolbarItem,
    quoteMobileToolbarItem,
    _nodeJotTemplateMobileToolbarItem,
  ];
}

final MobileToolbarItem _nodeJotTemplateMobileToolbarItem =
    MobileToolbarItem.withMenu(
      itemIconBuilder:
          (context, __, ___) => AFMobileIcon(
            afMobileIcons: AFMobileIcons.heading,
            color: MobileToolbarTheme.of(context).iconColor,
          ),
      itemMenuBuilder: (context, editorState, __) {
        final selection = editorState.selection;
        if (selection == null) {
          return const SizedBox.shrink();
        }
        return _NodeJotTemplateMenu(editorState: editorState);
      },
    );

/// NodeJot 模板节点菜单（手机端工具栏子菜单）。
class _NodeJotTemplateMenu extends StatelessWidget {
  const _NodeJotTemplateMenu({required this.editorState});

  final EditorState editorState;

  @override
  Widget build(BuildContext context) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final items = <_TemplateMenuItem>[
      _TemplateMenuItem(
        title: isZh ? '时间戳' : 'Timestamp',
        icon: AFMobileIcons.link,
        onTap: () => _insertTimestampTemplate(context, editorState),
      ),
      _TemplateMenuItem(
        title: isZh ? '提示块' : 'Hint Block',
        icon: AFMobileIcons.quote,
        onTap: () => _insertHintTemplate(context, editorState),
      ),
      _TemplateMenuItem(
        title: isZh ? '小节模板' : 'Section',
        icon: AFMobileIcons.h2,
        onTap: () => _insertSectionTemplate(context, editorState),
      ),
    ];

    return GridView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: buildMobileToolbarMenuGridDelegate(
        mobileToolbarStyle: MobileToolbarTheme.of(context),
        crossAxisCount: 2,
      ),
      children:
          items
              .map(
                (item) => MobileToolbarItemMenuBtn(
                  icon: AFMobileIcon(
                    afMobileIcons: item.icon,
                    color: MobileToolbarTheme.of(context).iconColor,
                  ),
                  label: Text(item.title),
                  isSelected: false,
                  onPressed: item.onTap,
                ),
              )
              .toList(growable: false),
    );
  }

  static void _insertTimestampTemplate(
    BuildContext context,
    EditorState editorState,
  ) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final formatted =
        '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}';
    _insertBlocksAfterSelection(editorState, [
      paragraphNode(text: isZh ? '时间：$formatted' : 'Time: $formatted'),
      paragraphNode(),
    ]);
  }

  static void _insertHintTemplate(BuildContext context, EditorState editorState) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    _insertBlocksAfterSelection(editorState, [
      paragraphNode(
        text: isZh ? '💡 提示：在这里输入你的重点信息。' : '💡 Hint: put key points here.',
      ),
      paragraphNode(),
    ]);
  }

  static void _insertSectionTemplate(
    BuildContext context,
    EditorState editorState,
  ) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    _insertBlocksAfterSelection(editorState, [
      headingNode(level: 2, text: isZh ? '小节标题' : 'Section Title'),
      paragraphNode(),
    ]);
  }

  /// 在当前光标所在块后插入一组块节点，并把光标移动到新内容首块。
  static void _insertBlocksAfterSelection(
    EditorState editorState,
    List<Node> nodes,
  ) {
    final selection = editorState.selection;
    if (selection == null || selection.end.path.isEmpty || nodes.isEmpty) {
      return;
    }

    final blockCount = editorState.document.root.children.length;
    final currentBlockIndex = selection.end.path.first;
    final clampedBlockIndex =
        currentBlockIndex < 0
            ? 0
            : (currentBlockIndex >= blockCount
                ? (blockCount == 0 ? 0 : blockCount - 1)
                : currentBlockIndex);
    final insertBlockIndex = blockCount == 0 ? 0 : clampedBlockIndex + 1;

    final copiedNodes = nodes.map((node) => node.copyWith()).toList();
    final transaction = editorState.transaction;
    transaction.insertNodes([insertBlockIndex], copiedNodes);
    transaction.afterSelection = Selection.single(
      path: [insertBlockIndex],
      startOffset: 0,
    );
    editorState.apply(transaction);
  }
}

class _TemplateMenuItem {
  const _TemplateMenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final AFMobileIcons icon;
  final VoidCallback onTap;
}
