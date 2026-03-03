import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_jot/core/utils/relative_time_formatter.dart';
import 'package:node_jot/l10n/app_localizations.dart';

void main() {
  group('RelativeTimeFormatter', () {
    final zh = AppLocalizations(const Locale('zh'));
    final en = AppLocalizations(const Locale('en'));
    final now = DateTime(2026, 3, 3, 12, 0, 0);

    test('shows just now for sub-minute diff', () {
      final text = RelativeTimeFormatter.formatUpdatedAt(
        updatedAt: now.subtract(const Duration(seconds: 30)),
        now: now,
        l10n: zh,
      );
      expect(text, '刚刚');
    });

    test('shows minutes ago', () {
      final text = RelativeTimeFormatter.formatUpdatedAt(
        updatedAt: now.subtract(const Duration(minutes: 5)),
        now: now,
        l10n: zh,
      );
      expect(text, '5分钟前');
    });

    test('shows hours ago', () {
      final text = RelativeTimeFormatter.formatUpdatedAt(
        updatedAt: now.subtract(const Duration(hours: 2)),
        now: now,
        l10n: zh,
      );
      expect(text, '2小时前');
    });

    test('shows days ago under threshold', () {
      final text = RelativeTimeFormatter.formatUpdatedAt(
        updatedAt: now.subtract(const Duration(days: 3)),
        now: now,
        l10n: zh,
      );
      expect(text, '3天前');
    });

    test('shows month-day when same year and beyond threshold', () {
      final text = RelativeTimeFormatter.formatUpdatedAt(
        updatedAt: now.subtract(const Duration(days: 8)),
        now: now,
        l10n: zh,
      );
      expect(text, '2月23日');
    });

    test('shows full date when not same year', () {
      final text = RelativeTimeFormatter.formatUpdatedAt(
        updatedAt: DateTime(2025, 12, 31, 12, 0, 0),
        now: now,
        l10n: zh,
      );
      expect(text, '2025-12-31');
    });

    test('shows just now for future timestamp', () {
      final text = RelativeTimeFormatter.formatUpdatedAt(
        updatedAt: now.add(const Duration(minutes: 10)),
        now: now,
        l10n: zh,
      );
      expect(text, '刚刚');
    });

    test('supports english month-day output', () {
      final text = RelativeTimeFormatter.formatUpdatedAt(
        updatedAt: now.subtract(const Duration(days: 8)),
        now: now,
        l10n: en,
      );
      expect(text, 'Feb 23');
    });
  });
}

