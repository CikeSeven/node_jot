class NoteCategoryCodec {
  NoteCategoryCodec._();

  static final RegExp _whitespaceRegex = RegExp(r'\s+');

  /// 规范化分类展示文案：trim + 空白折叠。
  static String normalizeLabel(String value) {
    final collapsed = value.replaceAll(_whitespaceRegex, ' ').trim();
    return collapsed;
  }

  /// 分类比较键（大小写不敏感）。
  static String toKey(String value) {
    final normalized = normalizeLabel(value);
    if (normalized.isEmpty) {
      return '';
    }
    return normalized.toLowerCase();
  }

  /// 规范化分类列表并按“首次出现”去重。
  static List<String> normalizeList(Iterable<String> values) {
    final output = <String>[];
    final seen = <String>{};
    for (final raw in values) {
      final normalized = normalizeLabel(raw);
      if (normalized.isEmpty) {
        continue;
      }
      final key = toKey(normalized);
      if (!seen.add(key)) {
        continue;
      }
      output.add(normalized);
    }
    return output;
  }

  static Set<String> toKeySet(Iterable<String> values) {
    final result = <String>{};
    for (final value in values) {
      final key = toKey(value);
      if (key.isNotEmpty) {
        result.add(key);
      }
    }
    return result;
  }

  static String signature(Iterable<String> values) {
    final normalized = normalizeList(values);
    if (normalized.isEmpty) {
      return '';
    }
    return normalized.map(toKey).join('\u001f');
  }

  static List<String> fromSnapshotValue(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    final raw = <String>[];
    for (final item in value) {
      if (item is String) {
        raw.add(item);
      }
    }
    return normalizeList(raw);
  }
}
