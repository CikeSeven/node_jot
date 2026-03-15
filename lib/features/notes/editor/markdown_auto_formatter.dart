import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart' as quill_delta;

/// Markdown 输入自动转换器。
///
/// 设计目标：
/// - 仅在关键触发字符（空格/回车/闭合符）时处理；
/// - 只解析当前行，避免整文扫描导致卡顿；
/// - 命中后删除 markdown 标记并应用 Quill 样式。
class MarkdownAutoFormatter {
  static const int _maxLineLength = 300;
  static const int _maxInsertedLength = 50;
  static const String _dividerFallback = '────────';

  bool _applying = false;

  bool applyIfNeeded({
    required quill.QuillController controller,
    required quill.DocChange change,
  }) {
    if (_applying || change.source != quill.ChangeSource.local) {
      return false;
    }

    final insertedText = _extractInsertedText(change.change);
    if (insertedText.isEmpty || insertedText.length > _maxInsertedLength) {
      return false;
    }

    final triggerBlock =
        insertedText.contains(' ') || insertedText.contains('\n');
    final triggerInline =
        insertedText.contains('*') || insertedText.contains('`');

    if (triggerBlock &&
        _runGuarded(() => _tryApplyBlockRule(controller, insertedText))) {
      return true;
    }

    if (triggerInline &&
        _runGuarded(() => _tryApplyInlineRule(controller, insertedText))) {
      return true;
    }

    return false;
  }

  bool _runGuarded(bool Function() action) {
    _applying = true;
    try {
      return action();
    } finally {
      _applying = false;
    }
  }

  String _extractInsertedText(quill_delta.Delta delta) {
    final buffer = StringBuffer();
    for (final operation in delta.operations) {
      if (!operation.isInsert) {
        continue;
      }
      final data = operation.data;
      if (data is String) {
        buffer.write(data);
      }
    }
    return buffer.toString();
  }

  bool _tryApplyBlockRule(
    quill.QuillController controller,
    String insertedText,
  ) {
    final plain = controller.document.toPlainText();
    if (plain.isEmpty) {
      return false;
    }

    var cursorOffset = controller.selection.baseOffset;
    if (insertedText.contains('\n')) {
      if (_repairHeaderLineStyleDriftAfterEnter(controller)) {
        return true;
      }
      cursorOffset -= 1;
    }

    if (cursorOffset < 0) {
      return false;
    }

    final line = _resolveLineContext(plain, cursorOffset);
    if (line.text.length > _maxLineLength) {
      return false;
    }

    final headerMatch = RegExp(r'^(#{1,3}) $').firstMatch(line.text);
    if (headerMatch != null) {
      final level = headerMatch.group(1)!.length;
      final attr =
          level == 1
              ? quill.Attribute.h1
              : (level == 2 ? quill.Attribute.h2 : quill.Attribute.h3);
      return _removePrefixAndApplyBlock(
        controller,
        line: line,
        prefixLength: headerMatch.group(0)!.length,
        attribute: attr,
      );
    }

    if (RegExp(r'^[-*] $').hasMatch(line.text)) {
      return _removePrefixAndApplyBlock(
        controller,
        line: line,
        prefixLength: 2,
        attribute: quill.Attribute.ul,
      );
    }

    if (RegExp(r'^1\. $').hasMatch(line.text)) {
      return _removePrefixAndApplyBlock(
        controller,
        line: line,
        prefixLength: 3,
        attribute: quill.Attribute.ol,
      );
    }

    if (RegExp(r'^> $').hasMatch(line.text)) {
      return _removePrefixAndApplyBlock(
        controller,
        line: line,
        prefixLength: 2,
        attribute: quill.Attribute.blockQuote,
      );
    }

    final checklist = RegExp(r'^- \[( |x|X)\] $').firstMatch(line.text);
    if (checklist != null) {
      final checked = checklist.group(1)!.toLowerCase() == 'x';
      return _removePrefixAndApplyBlock(
        controller,
        line: line,
        prefixLength: checklist.group(0)!.length,
        attribute:
            checked ? quill.Attribute.checked : quill.Attribute.unchecked,
      );
    }

    final trimmed = line.text.trim();
    if (trimmed == '```') {
      return _replaceLineAndApplyBlock(
        controller,
        line: line,
        replacement: '',
        attribute: quill.Attribute.codeBlock,
      );
    }

    if (trimmed == '---') {
      return _replaceLineAndApplyParagraph(
        controller,
        line: line,
        replacement: _dividerFallback,
      );
    }

    return false;
  }

  bool _repairHeaderLineStyleDriftAfterEnter(quill.QuillController controller) {
    final plain = controller.document.toPlainText();
    final currentLineStart = controller.selection.baseOffset;
    if (currentLineStart <= 0 || currentLineStart > plain.length) {
      return false;
    }

    final currentLine = _resolveLineContext(plain, currentLineStart);
    if (currentLine.text.isNotEmpty) {
      return false;
    }

    final previousLine = _resolveLineContext(plain, currentLineStart - 1);
    final previousHeader = _lineAttributeAt(
      controller.document,
      previousLine.start,
      quill.Attribute.header.key,
    );
    final currentHeader = _lineAttributeAt(
      controller.document,
      currentLine.start,
      quill.Attribute.header.key,
    );

    // 回车后若出现“标题属性漂移到下一空行”，将其回拨到上一行并清空当前行。
    if (previousHeader != null || currentHeader == null) {
      return false;
    }

    final previousLineBreak = _lineBreakIndexForLine(
      controller.document,
      previousLine.start,
    );
    final currentLineBreak = _lineBreakIndexForLine(
      controller.document,
      currentLine.start,
    );
    _clearExclusiveBlockStyles(controller, previousLineBreak);
    controller.formatText(previousLineBreak, 1, currentHeader);
    _clearExclusiveBlockStyles(controller, currentLineBreak);
    controller.updateSelection(
      TextSelection.collapsed(offset: currentLineStart),
      quill.ChangeSource.local,
    );
    return true;
  }

  bool _tryApplyInlineRule(
    quill.QuillController controller,
    String insertedText,
  ) {
    final plain = controller.document.toPlainText();
    final cursorOffset = controller.selection.baseOffset;
    if (plain.isEmpty || cursorOffset <= 0) {
      return false;
    }

    final line = _resolveLineContext(plain, cursorOffset);
    if (line.text.length > _maxLineLength || line.caretOffset <= 0) {
      return false;
    }

    final prefix = line.text.substring(0, line.caretOffset);

    if (insertedText.contains('*')) {
      final boldMatch = RegExp(r'\*\*([^*\n]+)\*\*$').firstMatch(prefix);
      if (boldMatch != null) {
        return _applyInlineWrap(
          controller: controller,
          line: line,
          match: boldMatch,
          wrapperLength: 2,
          attribute: quill.Attribute.bold,
        );
      }

      final italicMatch = RegExp(r'\*([^*\n]+)\*$').firstMatch(prefix);
      if (italicMatch != null) {
        final rawText = italicMatch.group(0)!;
        final rawStart = line.caretOffset - rawText.length;
        if (rawStart > 0 && line.text[rawStart - 1] == '*') {
          return false;
        }
        return _applyInlineWrap(
          controller: controller,
          line: line,
          match: italicMatch,
          wrapperLength: 1,
          attribute: quill.Attribute.italic,
        );
      }
    }

    if (insertedText.contains('`')) {
      final codeMatch = RegExp(r'`([^`\n]+)`$').firstMatch(prefix);
      if (codeMatch != null) {
        return _applyInlineWrap(
          controller: controller,
          line: line,
          match: codeMatch,
          wrapperLength: 1,
          attribute: quill.Attribute.inlineCode,
        );
      }
    }

    return false;
  }

  bool _applyInlineWrap({
    required quill.QuillController controller,
    required _LineContext line,
    required Match match,
    required int wrapperLength,
    required quill.Attribute attribute,
  }) {
    final raw = match.group(0)!;
    final content = match.group(1)!;
    final rawStart = line.caretOffset - raw.length;
    final absStart = line.start + rawStart;

    // 先删尾标记，再删头标记，避免索引偏移。
    controller.replaceText(
      absStart + raw.length - wrapperLength,
      wrapperLength,
      '',
      null,
    );
    controller.replaceText(absStart, wrapperLength, '', null);
    controller.formatText(absStart, content.length, attribute);
    controller.updateSelection(
      TextSelection.collapsed(offset: absStart + content.length),
      quill.ChangeSource.local,
    );
    return true;
  }

  bool _removePrefixAndApplyBlock(
    quill.QuillController controller, {
    required _LineContext line,
    required int prefixLength,
    required quill.Attribute attribute,
  }) {
    if (prefixLength <= 0 || prefixLength > line.text.length) {
      return false;
    }

    controller.replaceText(
      line.start,
      prefixLength,
      '',
      TextSelection.collapsed(offset: line.start),
    );

    final formatIndex = _lineBreakIndexForLine(controller.document, line.start);
    _clearExclusiveBlockStyles(controller, formatIndex);
    controller.formatText(formatIndex, 1, attribute);
    controller.updateSelection(
      TextSelection.collapsed(offset: line.start),
      quill.ChangeSource.local,
    );
    return true;
  }

  bool _replaceLineAndApplyBlock(
    quill.QuillController controller, {
    required _LineContext line,
    required String replacement,
    required quill.Attribute attribute,
  }) {
    controller.replaceText(
      line.start,
      line.text.length,
      replacement,
      TextSelection.collapsed(offset: line.start + replacement.length),
    );
    final formatIndex = _lineBreakIndexForLine(controller.document, line.start);
    _clearExclusiveBlockStyles(controller, formatIndex);
    controller.formatText(formatIndex, 1, attribute);
    controller.updateSelection(
      TextSelection.collapsed(offset: line.start + replacement.length),
      quill.ChangeSource.local,
    );
    return true;
  }

  bool _replaceLineAndApplyParagraph(
    quill.QuillController controller, {
    required _LineContext line,
    required String replacement,
  }) {
    controller.replaceText(
      line.start,
      line.text.length,
      replacement,
      TextSelection.collapsed(offset: line.start + replacement.length),
    );

    final formatIndex = _lineBreakIndexForLine(controller.document, line.start);
    _clearExclusiveBlockStyles(controller, formatIndex);
    controller.updateSelection(
      TextSelection.collapsed(offset: line.start + replacement.length),
      quill.ChangeSource.local,
    );
    return true;
  }

  void _clearExclusiveBlockStyles(quill.QuillController controller, int index) {
    controller.formatText(
      index,
      1,
      quill.Attribute.clone(quill.Attribute.header, null),
    );
    controller.formatText(
      index,
      1,
      quill.Attribute.clone(quill.Attribute.list, null),
    );
    controller.formatText(
      index,
      1,
      quill.Attribute.clone(quill.Attribute.blockQuote, null),
    );
    controller.formatText(
      index,
      1,
      quill.Attribute.clone(quill.Attribute.codeBlock, null),
    );
  }

  int _safeFormatIndex(quill.Document document, int preferredIndex) {
    final max = document.length - 1;
    if (max <= 0) {
      return 0;
    }
    return preferredIndex.clamp(0, max).toInt();
  }

  int _lineBreakIndexForLine(quill.Document document, int lineStart) {
    final plain = document.toPlainText();
    final safeStart = lineStart.clamp(0, plain.length).toInt();
    final lineBreak = plain.indexOf('\n', safeStart);
    if (lineBreak == -1) {
      return _safeFormatIndex(document, safeStart);
    }
    return _safeFormatIndex(document, lineBreak);
  }

  quill.Attribute? _lineAttributeAt(
    quill.Document document,
    int index,
    String attributeKey,
  ) {
    final safeIndex = _safeFormatIndex(document, index);
    final child = document.queryChild(safeIndex);
    return child.node?.style.attributes[attributeKey];
  }

  _LineContext _resolveLineContext(String plain, int offset) {
    final safeOffset = offset.clamp(0, plain.length).toInt();
    final startMarker = plain.lastIndexOf('\n', safeOffset - 1);
    final lineStart = startMarker == -1 ? 0 : startMarker + 1;
    var lineEnd = plain.indexOf('\n', safeOffset);
    if (lineEnd == -1) {
      lineEnd = plain.length;
    }

    final lineText = plain.substring(lineStart, lineEnd);
    final caretOffset = safeOffset - lineStart;
    return _LineContext(
      start: lineStart,
      end: lineEnd,
      text: lineText,
      caretOffset: caretOffset,
    );
  }
}

class _LineContext {
  const _LineContext({
    required this.start,
    required this.end,
    required this.text,
    required this.caretOffset,
  });

  final int start;
  final int end;
  final String text;
  final int caretOffset;
}
