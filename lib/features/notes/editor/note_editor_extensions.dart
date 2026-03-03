import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// 构建 NodeJot 的命令快捷键扩展集合。
///
/// 在标准命令基础上增加：
/// - `Ctrl/Cmd + S`：手动保存；
/// - 覆盖默认粘贴命令：交给上层的 Markdown 感知粘贴逻辑处理。
List<CommandShortcutEvent> buildNodeJotCommandShortcutEvents({
  required Future<void> Function() onSave,
  required Future<void> Function(EditorState editorState) onMarkdownAwarePaste,
}) {
  final commands = standardCommandShortcutEvents
      .where(
        (event) =>
            event.key != pasteCommand.key &&
            event.key != pasteTextWithoutFormattingCommand.key,
      )
      .toList(growable: true);

  commands.insert(
    0,
    CommandShortcutEvent(
      key: 'nodejot-save',
      command: 'ctrl+s',
      windowsCommand: 'ctrl+s',
      macOSCommand: 'cmd+s',
      linuxCommand: 'ctrl+s',
      getDescription: () => 'Save current note',
      handler: (editorState) {
        unawaited(onSave());
        return KeyEventResult.handled;
      },
    ),
  );

  commands.insert(
    0,
    CommandShortcutEvent(
      key: pasteCommand.key,
      command: 'ctrl+v',
      windowsCommand: 'ctrl+v',
      macOSCommand: 'cmd+v',
      linuxCommand: 'ctrl+v',
      getDescription: () => 'NodeJot Markdown-aware paste',
      handler: (editorState) {
        unawaited(onMarkdownAwarePaste(editorState));
        return KeyEventResult.handled;
      },
    ),
  );

  commands.insert(
    0,
    CommandShortcutEvent(
      key: pasteTextWithoutFormattingCommand.key,
      command: 'ctrl+shift+v',
      windowsCommand: 'ctrl+shift+v',
      macOSCommand: 'cmd+shift+v',
      linuxCommand: 'ctrl+shift+v',
      getDescription: () => 'NodeJot Markdown-aware plain paste',
      handler: (editorState) {
        unawaited(onMarkdownAwarePaste(editorState));
        return KeyEventResult.handled;
      },
    ),
  );

  return commands;
}

/// 构建 NodeJot 的字符快捷键扩展集合。
///
/// 当前保留 AppFlowy 默认 slash 菜单项，避免误导性“代码”入口。
List<CharacterShortcutEvent> buildNodeJotCharacterShortcutEvents({
  required Brightness brightness,
}) {
  final events =
      standardCharacterShortcutEvents
          .where((event) => event.key != slashCommand.key)
          .toList(growable: true);

  events.insert(
    0,
    customSlashCommand(
      standardSelectionMenuItems,
      shouldInsertSlash: true,
      deleteKeywordsByDefault: true,
      singleColumn: true,
      style:
          brightness == Brightness.dark
              ? SelectionMenuStyle.dark
              : SelectionMenuStyle.light,
    ),
  );

  return events;
}
