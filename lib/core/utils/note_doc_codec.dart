import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart' as quill_delta;

/// 文档转换结果。
class NoteDocSnapshot {
  const NoteDocSnapshot({
    required this.contentDocJson,
    required this.contentMd,
    required this.displayTitle,
    required this.previewText,
    required this.contentFormat,
    required this.schemaVersion,
  });

  final String contentDocJson;
  final String contentMd;
  final String displayTitle;
  final String previewText;
  final String contentFormat;
  final int schemaVersion;
}

/// Markdown、Quill Delta 与旧版结构化文档的转换工具。
class NoteDocCodec {
  /// 当前文档结构版本。
  static const int schemaVersion = 3;

  /// 持久化内容格式标识（用于后续扩展多格式兼容）。
  static const String contentFormat = 'quill_delta';

  /// 新建笔记默认标题。
  static const String defaultHeading = '未命名笔记';

  /// 构建新笔记的默认 markdown 模板（H1 + 空行）。
  static String buildNewNoteMarkdown({String heading = defaultHeading}) {
    final normalized = _normalizeHeading(heading);
    return '# $normalized\n\n';
  }

  /// 从 markdown 中提取用于列表显示的标题。
  static String extractDisplayTitle(String markdown) {
    return _extractDisplayTitle(markdown);
  }

  /// 从 markdown 中提取预览摘要文本。
  static String extractPreviewText(String markdown) {
    return _extractPreviewText(markdown);
  }

  /// 判断给定文本是否“看起来像 markdown 源文本”。
  static bool isLikelyMarkdownSource(String source) {
    return _isLikelyMarkdownSource(source);
  }

  /// 兼容旧版字段（title + contentMd）并拼装为完整 markdown。
  static String buildMarkdownFromLegacy({
    required String? title,
    required String contentMd,
  }) {
    final normalizedTitle = _normalizeHeading(title);
    final trimmed = contentMd.trim();
    if (trimmed.startsWith('# ')) {
      return contentMd;
    }
    if (trimmed.isEmpty) {
      return buildNewNoteMarkdown(heading: normalizedTitle);
    }
    return '# $normalizedTitle\n\n$contentMd';
  }

  /// 从 markdown 直接生成文档快照。
  static NoteDocSnapshot fromMarkdown(String markdown) {
    final document = _buildQuillDocumentFromMarkdown(
      markdown,
      fallbackHeading: defaultHeading,
    );
    return fromDocument(document);
  }

  /// 从结构化文档生成存储快照。
  static NoteDocSnapshot fromDocument(quill.Document document) {
    final normalized = _ensureEditableDocument(
      document,
      fallbackHeading: defaultHeading,
    );
    final summary = _summarizeDocument(normalized);
    final markdown = _buildMarkdown(summary.title, summary.bodyLines);
    return NoteDocSnapshot(
      contentDocJson: jsonEncode(normalized.toDelta().toJson()),
      contentMd: markdown,
      displayTitle: summary.title,
      previewText: summary.preview,
      contentFormat: contentFormat,
      schemaVersion: schemaVersion,
    );
  }

  /// 从存储层 docJson 恢复快照，失败时回退 markdown 路径。
  static NoteDocSnapshot fromDocJson({
    required String docJson,
    String? fallbackMarkdown,
    String? fallbackTitle,
  }) {
    final heading = _normalizeHeading(fallbackTitle);
    final fallback = fallbackMarkdown ?? buildNewNoteMarkdown(heading: heading);
    final document = _decodeDocumentInternal(
      contentDocJson: docJson,
      fallbackMarkdown: fallback,
      fallbackHeading: heading,
    );
    return fromDocument(document);
  }

  static quill.Document decodeDocument({
    String? contentDocJson,
    String? fallbackMarkdown,
    String? fallbackTitle,
  }) {
    final heading = _normalizeHeading(fallbackTitle);
    final fallback = fallbackMarkdown ?? buildNewNoteMarkdown(heading: heading);
    return _decodeDocumentInternal(
      contentDocJson: contentDocJson,
      fallbackMarkdown: fallback,
      fallbackHeading: heading,
    );
  }

  /// 构造一个“标题 + 空行”的初始文档。
  static quill.Document buildInitialDocument({
    String heading = defaultHeading,
  }) {
    final normalized = _normalizeHeading(heading);
    return _buildQuillDocumentFromPlainText('$normalized\n\n');
  }

  static quill.Document _decodeDocumentInternal({
    required String? contentDocJson,
    required String fallbackMarkdown,
    required String fallbackHeading,
  }) {
    final fallbackDocument = _buildQuillDocumentFromMarkdown(
      fallbackMarkdown,
      fallbackHeading: fallbackHeading,
    );

    if (contentDocJson == null || contentDocJson.trim().isEmpty) {
      return fallbackDocument;
    }

    try {
      final raw = jsonDecode(contentDocJson);

      // 新格式：Quill Delta JSON（List）。
      if (raw is List) {
        final document = quill.Document.fromJson(raw);
        return _ensureEditableDocument(
          document,
          fallbackHeading: fallbackHeading,
        );
      }

      // 旧格式：结构化块文档（Map）。
      if (raw is Map<String, dynamic>) {
        final markdown = _decodeLegacyStructuredDocToMarkdown(
          raw,
          fallbackHeading: fallbackHeading,
          fallbackMarkdown: fallbackMarkdown,
        );
        return _buildQuillDocumentFromMarkdown(
          markdown,
          fallbackHeading: fallbackHeading,
        );
      }
    } catch (_) {
      // ignore and fallback.
    }

    return fallbackDocument;
  }

  static String _decodeLegacyStructuredDocToMarkdown(
    Map<String, dynamic> raw, {
    required String fallbackHeading,
    required String fallbackMarkdown,
  }) {
    final richMarkdown = _decodeLegacyStructuredDocWithBlockSemantics(
      raw,
      fallbackHeading: fallbackHeading,
    );
    if (richMarkdown != null && richMarkdown.trim().isNotEmpty) {
      return _preferRicherMarkdown(
        candidate: richMarkdown,
        fallback: fallbackMarkdown,
      );
    }

    final lines = _collectLegacyTextLines(raw);
    final nonEmpty = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (nonEmpty.isEmpty) {
      return fallbackMarkdown;
    }

    final title = nonEmpty.first;
    final body = nonEmpty.length > 1 ? nonEmpty.sublist(1) : const <String>[];
    final decoded = _buildMarkdown(title, body);
    return _preferRicherMarkdown(
      candidate: decoded,
      fallback: fallbackMarkdown,
    );
  }

  static String? _decodeLegacyStructuredDocWithBlockSemantics(
    Map<String, dynamic> raw, {
    required String fallbackHeading,
  }) {
    final lines = <String>[];
    final rootChildren = raw['children'];
    if (rootChildren is List && rootChildren.isNotEmpty) {
      _collectLegacyBlockLines(rootChildren, lines);
    } else {
      _collectLegacyBlockLines(raw, lines);
    }
    final normalized = lines
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) {
      return null;
    }
    return _buildMarkdownFromLegacyBlockLines(
      lines: normalized,
      fallbackHeading: fallbackHeading,
    );
  }

  static void _collectLegacyBlockLines(Object? raw, List<String> lines) {
    if (raw is List) {
      for (final item in raw) {
        _collectLegacyBlockLines(item, lines);
      }
      return;
    }
    if (raw is! Map) {
      return;
    }

    final map = raw.cast<Object?, Object?>();
    final text = _extractLegacyNodeText(map);
    final prefix = _legacyMarkdownPrefix(map);
    if (text != null && text.trim().isNotEmpty) {
      final textLines = text.replaceAll('\r\n', '\n').split('\n');
      for (final line in textLines) {
        final normalized = line.trim();
        if (normalized.isEmpty) {
          continue;
        }
        lines.add('$prefix$normalized');
      }
    }

    final children = map['children'];
    if (children is List && children.isNotEmpty) {
      _collectLegacyBlockLines(children, lines);
    }
  }

  static String? _extractLegacyNodeText(Map<Object?, Object?> map) {
    final deltaCandidates = <Object?>[
      map['delta'],
      map['ops'],
      map['data'] is Map ? (map['data'] as Map)['delta'] : null,
      map['data'] is Map ? (map['data'] as Map)['ops'] : null,
    ];
    for (final candidate in deltaCandidates) {
      final text = _extractLegacyDeltaText(candidate);
      if (text.trim().isNotEmpty) {
        return text;
      }
    }

    final textCandidates = <Object?>[
      map['text'],
      map['insert'],
      map['title'],
      map['data'] is Map ? (map['data'] as Map)['text'] : null,
      map['data'] is Map ? (map['data'] as Map)['insert'] : null,
      map['data'] is Map ? (map['data'] as Map)['title'] : null,
    ];
    for (final candidate in textCandidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  static String _legacyMarkdownPrefix(Map<Object?, Object?> map) {
    final hints = _legacyTypeHints(map);

    if (_legacyContainsAny(hints, const ['heading', 'title'])) {
      final level = _legacyHeadingLevel(map, hints);
      return '${'#' * level} ';
    }

    if (_legacyContainsAny(hints, const [
      'todo',
      'checkbox',
      'checklist',
      'check_list',
      'task',
    ])) {
      final checked = _legacyCheckedState(map);
      return checked ? '- [x] ' : '- [ ] ';
    }

    if (_legacyContainsAny(hints, const ['numbered', 'ordered', 'ol'])) {
      return '1. ';
    }

    if (_legacyContainsAny(hints, const ['bulleted', 'bullet', 'unordered'])) {
      return '- ';
    }

    if (_legacyContainsAny(hints, const ['quote', 'blockquote'])) {
      return '> ';
    }

    return '';
  }

  static String _legacyTypeHints(Map<Object?, Object?> map) {
    final values = <String>[];
    void push(Object? value) {
      if (value is String && value.trim().isNotEmpty) {
        values.add(value.trim().toLowerCase());
      }
    }

    push(map['type']);
    push(map['subtype']);
    push(map['kind']);
    push(map['style']);
    final data = map['data'];
    if (data is Map) {
      push(data['type']);
      push(data['subtype']);
      push(data['kind']);
      push(data['style']);
    }
    return values.join('|');
  }

  static bool _legacyContainsAny(String hints, List<String> needles) {
    for (final needle in needles) {
      if (hints.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  static int _legacyHeadingLevel(Map<Object?, Object?> map, String hints) {
    int? readLevel(Object? value) {
      if (value is int) {
        return value;
      }
      if (value is double) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
      return null;
    }

    final directCandidates = <Object?>[
      map['level'],
      map['headingLevel'],
      map['heading_level'],
    ];
    for (final candidate in directCandidates) {
      final level = readLevel(candidate);
      if (level != null) {
        return level.clamp(1, 3);
      }
    }

    final data = map['data'];
    if (data is Map) {
      final dataCandidates = <Object?>[
        data['level'],
        data['headingLevel'],
        data['heading_level'],
      ];
      for (final candidate in dataCandidates) {
        final level = readLevel(candidate);
        if (level != null) {
          return level.clamp(1, 3);
        }
      }
    }

    final hintMatch = RegExp(
      r'(?:^|[^a-z])h([1-6])(?:[^a-z]|$)',
    ).firstMatch(hints);
    if (hintMatch != null) {
      final parsed = int.tryParse(hintMatch.group(1)!);
      if (parsed != null) {
        return parsed.clamp(1, 3);
      }
    }
    return 1;
  }

  static bool _legacyCheckedState(Map<Object?, Object?> map) {
    bool? readBool(Object? value) {
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
          return true;
        }
        if (normalized == 'false' || normalized == '0' || normalized == 'no') {
          return false;
        }
      }
      return null;
    }

    final directCandidates = <Object?>[
      map['checked'],
      map['isChecked'],
      map['completed'],
      map['done'],
    ];
    for (final candidate in directCandidates) {
      final checked = readBool(candidate);
      if (checked != null) {
        return checked;
      }
    }

    final data = map['data'];
    if (data is Map) {
      final dataCandidates = <Object?>[
        data['checked'],
        data['isChecked'],
        data['completed'],
        data['done'],
      ];
      for (final candidate in dataCandidates) {
        final checked = readBool(candidate);
        if (checked != null) {
          return checked;
        }
      }
    }
    return false;
  }

  static String _buildMarkdownFromLegacyBlockLines({
    required List<String> lines,
    required String fallbackHeading,
  }) {
    if (lines.isEmpty) {
      return buildNewNoteMarkdown(heading: fallbackHeading);
    }

    final firstLine = lines.first.trim();
    if (RegExp(r'^#{1,6}\s+\S').hasMatch(firstLine)) {
      if (lines.length <= 1) {
        return lines.join('\n');
      }
      final rest = lines.skip(1).join('\n');
      return '$firstLine\n\n$rest';
    }

    final heading = _normalizeHeading(fallbackHeading);
    final body =
        firstLine == heading
            ? lines.skip(1).toList(growable: false)
            : lines.toList(growable: false);
    if (body.isEmpty) {
      return buildNewNoteMarkdown(heading: heading);
    }
    return '# $heading\n\n${body.join('\n')}';
  }

  static List<String> _collectLegacyTextLines(Object? raw) {
    final lines = <String>[];
    _collectLegacyTextLinesRecursive(raw, lines);
    return lines;
  }

  static void _collectLegacyTextLinesRecursive(
    Object? raw,
    List<String> lines,
  ) {
    if (raw is List) {
      for (final item in raw) {
        _collectLegacyTextLinesRecursive(item, lines);
      }
      return;
    }

    if (raw is! Map) {
      return;
    }

    final map = raw.cast<Object?, Object?>();
    final handledKeys = <String>{};

    final inlineText = map['text'];
    if (inlineText is String && inlineText.trim().isNotEmpty) {
      lines.add(inlineText.trim());
      handledKeys.add('text');
    }

    final insertText = map['insert'];
    if (insertText is String && insertText.trim().isNotEmpty) {
      final split = insertText
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty);
      lines.addAll(split);
      handledKeys.add('insert');
    }

    final deltaCandidates = <Object?>[
      map['delta'],
      map['ops'],
      map['data'] is Map ? (map['data'] as Map)['delta'] : null,
      map['data'] is Map ? (map['data'] as Map)['ops'] : null,
    ];
    for (final candidate in deltaCandidates) {
      final deltaText = _extractLegacyDeltaText(candidate);
      if (deltaText.isEmpty) {
        continue;
      }
      final split = deltaText
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty);
      lines.addAll(split);
    }
    handledKeys
      ..add('delta')
      ..add('ops')
      ..add('data');

    for (final entry in map.entries) {
      final key = entry.key?.toString();
      if (key != null && handledKeys.contains(key)) {
        continue;
      }
      _collectLegacyTextLinesRecursive(entry.value, lines);
    }
  }

  static String _extractLegacyDeltaText(Object? rawDelta) {
    List<dynamic>? ops;
    if (rawDelta is List) {
      ops = rawDelta;
    } else if (rawDelta is Map<String, dynamic> && rawDelta['ops'] is List) {
      ops = rawDelta['ops'] as List<dynamic>;
    }
    if (ops == null || ops.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (final op in ops) {
      if (op is! Map) {
        continue;
      }
      final insert = op['insert'];
      if (insert is String) {
        buffer.write(insert);
      } else if (insert is Map && insert['text'] is String) {
        buffer.write(insert['text'] as String);
      }
    }

    return buffer.toString().replaceAll('\r\n', '\n').trimRight();
  }

  static quill.Document _buildQuillDocumentFromMarkdown(
    String markdown, {
    required String fallbackHeading,
  }) {
    final normalized = markdown.replaceAll('\r\n', '\n').trimRight();
    if (normalized.trim().isEmpty) {
      return buildInitialDocument(heading: fallbackHeading);
    }

    final lines = normalized.split('\n');
    final delta = quill_delta.Delta();
    var inCodeBlock = false;

    for (final rawLine in lines) {
      final parsed = _parseMarkdownBlockLine(
        rawLine.trimRight(),
        inCodeBlock: inCodeBlock,
      );
      if (parsed.isCodeFenceMarker) {
        inCodeBlock = !inCodeBlock;
        continue;
      }

      if (parsed.text.isNotEmpty) {
        delta.insert(parsed.text);
      }
      if (parsed.blockAttribute == null) {
        delta.insert('\n');
      } else {
        delta.insert('\n', {
          parsed.blockAttribute!.key: parsed.blockAttribute!.value,
        });
      }
    }

    if (delta.isEmpty) {
      return buildInitialDocument(heading: fallbackHeading);
    }
    final document = quill.Document.fromDelta(delta);
    return _ensureEditableDocument(document, fallbackHeading: fallbackHeading);
  }

  static _MarkdownBlockLine _parseMarkdownBlockLine(
    String line, {
    required bool inCodeBlock,
  }) {
    if (RegExp(r'^\s*```').hasMatch(line)) {
      return const _MarkdownBlockLine(
        text: '',
        blockAttribute: null,
        isCodeFenceMarker: true,
      );
    }

    if (inCodeBlock) {
      return _MarkdownBlockLine(
        text: line,
        blockAttribute: quill.Attribute.codeBlock,
      );
    }

    final headerMatch = RegExp(r'^\s{0,3}(#{1,3})\s*(.*)$').firstMatch(line);
    if (headerMatch != null) {
      final level = headerMatch.group(1)!.length;
      final text = headerMatch.group(2) ?? '';
      final attr =
          level == 1
              ? quill.Attribute.h1
              : (level == 2 ? quill.Attribute.h2 : quill.Attribute.h3);
      return _MarkdownBlockLine(text: text, blockAttribute: attr);
    }

    final checklist = RegExp(r'^\s*-\s\[( |x|X)\]\s+(.*)$').firstMatch(line);
    if (checklist != null) {
      final checked = checklist.group(1)!.toLowerCase() == 'x';
      return _MarkdownBlockLine(
        text: checklist.group(2) ?? '',
        blockAttribute:
            checked ? quill.Attribute.checked : quill.Attribute.unchecked,
      );
    }

    final ulMatch = RegExp(r'^\s*[-*+]\s+(.*)$').firstMatch(line);
    if (ulMatch != null) {
      return _MarkdownBlockLine(
        text: ulMatch.group(1) ?? '',
        blockAttribute: quill.Attribute.ul,
      );
    }

    final olMatch = RegExp(r'^\s*\d+\.\s+(.*)$').firstMatch(line);
    if (olMatch != null) {
      return _MarkdownBlockLine(
        text: olMatch.group(1) ?? '',
        blockAttribute: quill.Attribute.ol,
      );
    }

    final quoteMatch = RegExp(r'^\s*>\s?(.*)$').firstMatch(line);
    if (quoteMatch != null) {
      return _MarkdownBlockLine(
        text: quoteMatch.group(1) ?? '',
        blockAttribute: quill.Attribute.blockQuote,
      );
    }

    return _MarkdownBlockLine(text: line, blockAttribute: null);
  }

  static quill.Document _buildQuillDocumentFromPlainText(String source) {
    var text = source.replaceAll('\r\n', '\n');
    if (text.trim().isEmpty) {
      text = '$defaultHeading\n\n';
    }
    if (!text.endsWith('\n')) {
      text = '$text\n';
    }
    return quill.Document.fromDelta(quill_delta.Delta()..insert(text));
  }

  static quill.Document _ensureEditableDocument(
    quill.Document document, {
    required String fallbackHeading,
  }) {
    final plain = document.toPlainText().replaceAll(RegExp(r'\s+'), '');
    if (plain.isNotEmpty) {
      return document;
    }
    return buildInitialDocument(heading: fallbackHeading);
  }

  static _DocumentSummary _summarizeDocument(quill.Document document) {
    final lines = _normalizePlainTextLines(document.toPlainText());
    var title = defaultHeading;
    var titleIndex = -1;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        continue;
      }
      title = line;
      titleIndex = i;
      break;
    }

    final bodyLines = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || i == titleIndex) {
        continue;
      }
      bodyLines.add(line);
    }

    final preview =
        bodyLines.take(4).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return _DocumentSummary(
      title: title,
      preview: preview,
      bodyLines: bodyLines,
    );
  }

  static List<String> _normalizePlainTextLines(String plainText) {
    return plainText.replaceAll('\r\n', '\n').split('\n');
  }

  static String _buildMarkdown(String title, List<String> bodyLines) {
    final normalizedTitle = _normalizeHeading(title);
    if (bodyLines.isEmpty) {
      return '# $normalizedTitle\n\n';
    }
    return '# $normalizedTitle\n\n${bodyLines.join('\n')}';
  }

  static String _normalizeHeading(String? heading) {
    final text = (heading ?? '').trim();
    return text.isEmpty ? defaultHeading : text;
  }

  static String _extractDisplayTitle(String markdown) {
    final lines = markdown.split('\n');
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        continue;
      }
      if (line.startsWith('# ')) {
        final value = line.substring(2).trim();
        return value.isEmpty ? defaultHeading : value;
      }
      break;
    }
    return defaultHeading;
  }

  static String _extractPreviewText(String markdown) {
    final lines = markdown.split('\n');
    final filtered = <String>[];
    var skippedHeading = false;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        continue;
      }
      if (!skippedHeading && line.startsWith('# ')) {
        skippedHeading = true;
        continue;
      }
      filtered.add(line);
      if (filtered.length >= 4) {
        break;
      }
    }

    final joined = filtered.join(' ');
    final plain =
        joined
            .replaceAll(RegExp(r'[*_`>#\-\[\]\(\)!]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    return plain;
  }

  static bool _isLikelyMarkdownSource(String source) {
    if (source.isEmpty) {
      return false;
    }

    const linePatterns = <String>[
      r'^\s{0,3}#{1,6}\s+\S',
      r'^\s*[-*+]\s+\S',
      r'^\s*\d+\.\s+\S',
      r'^\s*>\s+\S',
      r'^\s*```',
      r'^\s*\|.+\|\s*$',
      r'^\s*[-*_]{3,}\s*$',
      r'^\s*-\s\[(?: |x|X)\]\s+\S',
    ];

    for (final pattern in linePatterns) {
      if (RegExp(pattern, multiLine: true).hasMatch(source)) {
        return true;
      }
    }

    var inlineHits = 0;
    const inlinePatterns = <String>[
      r'\[[^\]]+\]\([^)]+\)',
      r'`[^`\n]+`',
      r'\*\*[^*\n]+\*\*',
      r'(?<!\*)\*[^*\n]+\*(?!\*)',
      r'__(?!_).+?__(?!_)',
      r'(?<!_)_[^_\n]+_(?!_)',
    ];
    for (final pattern in inlinePatterns) {
      if (RegExp(pattern).hasMatch(source)) {
        inlineHits += 1;
      }
    }
    return inlineHits >= 2;
  }

  static String _preferRicherMarkdown({
    required String candidate,
    required String fallback,
  }) {
    final candidateScore = _markdownRichnessScore(candidate);
    final fallbackScore = _markdownRichnessScore(fallback);
    if (fallbackScore > candidateScore + 20) {
      return fallback;
    }
    return candidate;
  }

  static int _markdownRichnessScore(String markdown) {
    final nonWhitespaceLength =
        _markdownToPlainText(markdown).replaceAll(RegExp(r'\s+'), '').length;
    final nonEmptyLines =
        markdown
            .replaceAll('\r\n', '\n')
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .length;
    final blockMarkerLines =
        markdown.replaceAll('\r\n', '\n').split('\n').where((line) {
          final normalized = line.trimLeft();
          return normalized.startsWith('- [ ] ') ||
              normalized.startsWith('- [x] ') ||
              RegExp(r'^[-*+]\s+\S').hasMatch(normalized) ||
              RegExp(r'^\d+\.\s+\S').hasMatch(normalized) ||
              RegExp(r'^>\s*\S').hasMatch(normalized) ||
              RegExp(r'^#{1,6}\s+\S').hasMatch(normalized);
        }).length;
    return nonWhitespaceLength + nonEmptyLines * 1000 + blockMarkerLines * 300;
  }

  static String _markdownToPlainText(String markdown) {
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final normalized = <String>[];

    for (final rawLine in lines) {
      var line = rawLine.trimRight();

      line = line.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '');
      line = line.replaceFirst(RegExp(r'^\s*>\s?'), '');
      line = line.replaceFirst(RegExp(r'^\s*[-*+]\s+'), '');
      line = line.replaceFirst(RegExp(r'^\s*\d+\.\s+'), '');
      line = line.replaceFirst(RegExp(r'^\s*-\s\[(?: |x|X)\]\s+'), '');
      line = line.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), r'$1');
      line = line.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
      line = line.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
      line = line.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
      line = line.replaceAll(RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)'), r'$1');
      line = line.replaceAll(RegExp(r'__(?!_)(.+?)__(?!_)'), r'$1');
      line = line.replaceAll(RegExp(r'(?<!_)_([^_]+)_(?!_)'), r'$1');

      normalized.add(line);
    }

    return normalized.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}

class _DocumentSummary {
  const _DocumentSummary({
    required this.title,
    required this.preview,
    required this.bodyLines,
  });

  final String title;
  final String preview;
  final List<String> bodyLines;
}

class _MarkdownBlockLine {
  const _MarkdownBlockLine({
    required this.text,
    required this.blockAttribute,
    this.isCodeFenceMarker = false,
  });

  final String text;
  final quill.Attribute? blockAttribute;
  final bool isCodeFenceMarker;
}
