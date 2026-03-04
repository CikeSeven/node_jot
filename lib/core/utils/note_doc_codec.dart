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
  /// 当前文档结构版本。
  static const int schemaVersion = 2;

  /// 持久化内容格式标识（用于后续扩展多格式兼容）。
  static const String contentFormat = 'appflowy_doc';

  /// 新建笔记默认标题。
  static const String defaultHeading = '未命名笔记';

  /// 构建新笔记的默认 markdown 模板（H1 + 空行）。
  static String buildNewNoteMarkdown({String heading = defaultHeading}) {
    return '# ${heading.trim().isEmpty ? defaultHeading : heading.trim()}\n\n';
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
  ///
  /// 该方法主要用于粘贴场景下的轻量识别：
  /// - 命中标题/列表/引用/代码块等行级语法时返回 `true`；
  /// - 未命中行级语法时，会结合行内语法做次级判断。
  static bool isLikelyMarkdownSource(String source) {
    return _isLikelyMarkdownSource(source);
  }

  /// 兼容旧版字段（title + contentMd）并拼装为完整 markdown。
  ///
  /// 规则：
  /// - 若正文本身已以 `# ` 开头，认为已含标题，不重复注入；
  /// - 若正文为空，返回默认模板；
  /// - 否则拼接为“# 标题 + 正文”结构。
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

  /// 从 markdown 直接生成文档快照。
  ///
  /// 主要用于：
  /// - 外部导入 markdown；
  /// - docJson 解析失败时的回退路径。
  static NoteDocSnapshot fromMarkdown(String markdown) {
    final document = _ensureEditableDocument(
      AppFlowyEditorMarkdownCodec().decode(markdown),
      fallbackHeading: defaultHeading,
    );
    return fromDocument(document);
  }

  /// 从结构化文档生成存储快照。
  ///
  /// 输出包括：
  /// - `contentDocJson`：结构化持久化内容（主存储）；
  /// - `contentMd`：markdown 镜像（用于跨端兼容/预览）；
  /// - `displayTitle/previewText`：列表展示所需派生字段。
  static NoteDocSnapshot fromDocument(Document document) {
    final summary = _summarizeDocument(document);
    final markdown = _encodeMarkdownBestEffort(
      document: document,
      fallbackTitle: summary.title,
      bodyLines: summary.bodyLines,
    );
    return NoteDocSnapshot(
      contentDocJson: jsonEncode(document.toJson()),
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
    // fallback 路径始终保证可编辑：至少有 H1 + 段落。
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
          // 优先按结构化文档恢复。
          final document = _ensureEditableDocument(
            Document.fromJson(raw),
            fallbackHeading: normalizedHeading,
          );
          // 旧版本可能写入了非 page/block 结构，直接回退到 markdown 兼容路径。
          if (_looksLikeRenderableBlockDocument(document)) {
            return document;
          }
        }
      } catch (_) {
        // docJson 无法解析时回退到 markdown，确保旧数据可读。
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
        children: [headingNode(level: 1, text: normalized), paragraphNode()],
      ),
    );
  }

  static Document _ensureEditableDocument(
    Document document, {
    required String fallbackHeading,
  }) {
    // AppFlowy 要求根节点下有可编辑块；空文档时补初始模板。
    if (document.root.children.isNotEmpty) {
      return document;
    }
    return buildInitialDocument(heading: fallbackHeading);
  }

  static String _extractDisplayTitle(String markdown) {
    // 优先取第一条 H1；否则回退默认标题。
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
    // 预览规则：跳过首个 H1，抓取最多 4 行有效内容并去 markdown 符号。
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

  static bool _looksLikeRenderableBlockDocument(Document document) {
    if (document.root.children.isEmpty) {
      return false;
    }
    // 最常见的错误结构是顶层直接为 text 节点，这在 AppFlowy 中不可作为块渲染。
    for (final node in document.root.children) {
      if (node.type == 'text') {
        return false;
      }
    }
    return true;
  }

  static _DocumentSummary _summarizeDocument(Document document) {
    // 先找第一条非空 H1 作为标题；若无 H1，退化为首条非空块文本。
    final blocks = document.root.children;
    var title = defaultHeading;
    var titleIndex = -1;

    for (var i = 0; i < blocks.length; i++) {
      final text = _nodePlainText(blocks[i]);
      if (text.isEmpty) {
        continue;
      }
      final level = (blocks[i].attributes['level'] as num?)?.toInt();
      final isH1 = blocks[i].type == 'heading' && level == 1;
      if (isH1) {
        title = text;
        titleIndex = i;
        break;
      }
      if (titleIndex == -1) {
        title = text;
        titleIndex = i;
      }
    }

    final bodyLines = <String>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i == titleIndex) {
        continue;
      }
      final text = _nodePlainText(blocks[i]);
      if (text.isEmpty) {
        continue;
      }
      bodyLines.add(text);
    }

    final preview =
        bodyLines.take(4).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return _DocumentSummary(
      title: title,
      preview: preview,
      bodyLines: bodyLines,
    );
  }

  static String _nodePlainText(Node node) {
    // 递归压平节点文本并规范空白，得到用于列表展示的纯文本。
    final parts = <String>[];

    final delta = node.delta;
    if (delta != null) {
      final text =
          delta
              .toPlainText()
              .replaceAll('\n', ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
      if (text.isNotEmpty) {
        parts.add(text);
      }
    }

    for (final child in node.children) {
      final text = _nodePlainText(child);
      if (text.isNotEmpty) {
        parts.add(text);
      }
    }

    return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _isLikelyMarkdownSource(String source) {
    if (source.isEmpty) {
      return false;
    }

    // 逐行语法特征：标题、列表、引用、代码块、表格、分隔线、任务列表。
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

    // 行级不命中时，再检查行内语法；至少命中 2 条才认为是 markdown 原文。
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

  static String _encodeMarkdownBestEffort({
    required Document document,
    required String fallbackTitle,
    required List<String> bodyLines,
  }) {
    // 优先走官方 codec，失败时再走手工回退，避免保存链路中断。
    try {
      final markdown =
          AppFlowyEditorMarkdownCodec().encode(document).toString();
      if (markdown.trim().isNotEmpty) {
        return markdown;
      }
    } catch (_) {
      // 编码失败时使用回退 markdown。
    }

    final normalizedTitle =
        fallbackTitle.trim().isEmpty ? defaultHeading : fallbackTitle.trim();
    if (bodyLines.isEmpty) {
      return '# $normalizedTitle\n\n';
    }
    return '# $normalizedTitle\n\n${bodyLines.join('\n')}';
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
