import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';

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

/// Markdown 与 AppFlowy 文档的转换工具。
class NoteDocCodec {
  static const int schemaVersion = 2;
  static const String contentFormat = 'appflowy_doc';
  static const String defaultHeading = '标题';

  static String buildNewNoteMarkdown({String heading = defaultHeading}) {
    return '# ${heading.trim().isEmpty ? defaultHeading : heading.trim()}\n\n';
  }

  static String extractDisplayTitle(String markdown) {
    return _extractDisplayTitle(markdown);
  }

  static String extractPreviewText(String markdown) {
    return _extractPreviewText(markdown);
  }

  static String buildMarkdownFromLegacy({
    required String? title,
    required String contentMd,
  }) {
    final normalizedTitle =
        (title ?? '').trim().isEmpty ? defaultHeading : title!.trim();
    final trimmed = contentMd.trim();
    if (trimmed.startsWith('# ')) {
      return contentMd;
    }
    if (trimmed.isEmpty) {
      return buildNewNoteMarkdown(heading: normalizedTitle);
    }
    return '# $normalizedTitle\n\n$contentMd';
  }

  static NoteDocSnapshot fromMarkdown(String markdown) {
    final document = _ensureEditableDocument(
      AppFlowyEditorMarkdownCodec().decode(markdown),
      fallbackHeading: defaultHeading,
    );
    return fromDocument(document);
  }

  static NoteDocSnapshot fromDocument(Document document) {
    final markdown = AppFlowyEditorMarkdownCodec().encode(document).toString();
    final title = _extractDisplayTitle(markdown);
    final preview = _extractPreviewText(markdown);
    return NoteDocSnapshot(
      contentDocJson: jsonEncode(document.toJson()),
      contentMd: markdown,
      displayTitle: title,
      previewText: preview,
      contentFormat: contentFormat,
      schemaVersion: schemaVersion,
    );
  }

  static NoteDocSnapshot fromDocJson({
    required String docJson,
    String? fallbackMarkdown,
    String? fallbackTitle,
  }) {
    try {
      final raw = jsonDecode(docJson);
      if (raw is Map<String, dynamic>) {
        final document = _ensureEditableDocument(
          Document.fromJson(raw),
          fallbackHeading: fallbackTitle ?? defaultHeading,
        );
        return fromDocument(document);
      }
    } catch (_) {
      // ignore and fallback to markdown decode.
    }

    final markdown =
        fallbackMarkdown ??
        buildNewNoteMarkdown(
          heading:
              (fallbackTitle ?? '').trim().isEmpty
                  ? defaultHeading
                  : fallbackTitle!.trim(),
        );
    return fromMarkdown(markdown);
  }

  static Document decodeDocument({
    String? contentDocJson,
    String? fallbackMarkdown,
    String? fallbackTitle,
  }) {
    final normalizedHeading =
        (fallbackTitle ?? '').trim().isEmpty
            ? defaultHeading
            : fallbackTitle!.trim();
    final fallback =
        fallbackMarkdown ?? buildNewNoteMarkdown(heading: normalizedHeading);
    final fallbackDocument = _ensureEditableDocument(
      AppFlowyEditorMarkdownCodec().decode(fallback),
      fallbackHeading: normalizedHeading,
    );

    if (contentDocJson != null && contentDocJson.trim().isNotEmpty) {
      try {
        final raw = jsonDecode(contentDocJson);
        if (raw is Map<String, dynamic>) {
          final document = _ensureEditableDocument(
            Document.fromJson(raw),
            fallbackHeading: normalizedHeading,
          );
          final markdown = AppFlowyEditorMarkdownCodec().encode(document).toString().trim();
          // 旧数据中可能存在“可反序列化但不可渲染”的文档，空渲染时回退到 Markdown。
          if (markdown.isNotEmpty) {
            return document;
          }
        }
      } catch (_) {
        // ignore and fallback to markdown.
      }
    }
    return fallbackDocument;
  }

  /// 构造一个“标题 + 正文段落”的初始文档，保证编辑器必有可编辑节点。
  static Document buildInitialDocument({String heading = defaultHeading}) {
    final normalized = heading.trim().isEmpty ? defaultHeading : heading.trim();
    return Document(
      root: Node(
        type: 'page',
        children: [
          headingNode(level: 1, text: normalized),
          paragraphNode(),
        ],
      ),
    );
  }

  static Document _ensureEditableDocument(
    Document document, {
    required String fallbackHeading,
  }) {
    if (document.root.children.isNotEmpty) {
      return document;
    }
    return buildInitialDocument(heading: fallbackHeading);
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
    final plain = joined
        .replaceAll(RegExp(r'[*_`>#\-\[\]\(\)!]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return plain;
  }
}
