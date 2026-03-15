import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_jot/core/utils/note_doc_codec.dart';

void main() {
  group('NoteDocCodec migration', () {
    test('fromMarkdown keeps heading style for # title', () {
      final snapshot = NoteDocCodec.fromMarkdown('# Title\n\nBody line');
      final doc = quill.Document.fromJson(
        jsonDecode(snapshot.contentDocJson) as List<dynamic>,
      );

      expect(doc.toPlainText(), 'Title\n\nBody line\n');
      final ops = doc.toDelta().toJson();
      expect(ops[1]['insert'], '\n');
      expect(ops[1]['attributes']?['header'], 1);
    });

    test(
      'fromDocJson falls back to legacy markdown when legacy map is empty',
      () {
        const fallback = '# Legacy Title\n\nLine A\nLine B';
        final snapshot = NoteDocCodec.fromDocJson(
          docJson: jsonEncode({'type': 'document', 'children': []}),
          fallbackMarkdown: fallback,
          fallbackTitle: 'Legacy Title',
        );
        final doc = quill.Document.fromJson(
          jsonDecode(snapshot.contentDocJson) as List<dynamic>,
        );

        expect(doc.toPlainText(), 'Legacy Title\n\nLine A\nLine B\n');
      },
    );

    test('fromDocJson reads nested data.delta in legacy structured doc', () {
      final legacy = <String, dynamic>{
        'type': 'page',
        'children': [
          {
            'type': 'heading',
            'data': {
              'delta': [
                {'insert': 'Legacy Title'},
              ],
            },
          },
          {
            'type': 'paragraph',
            'data': {
              'delta': [
                {'insert': 'Line One'},
              ],
            },
          },
          {
            'type': 'paragraph',
            'data': {
              'delta': [
                {'insert': 'Line Two'},
              ],
            },
          },
        ],
      };

      final snapshot = NoteDocCodec.fromDocJson(
        docJson: jsonEncode(legacy),
        fallbackMarkdown: '# Fallback\n\nunused body',
      );
      final doc = quill.Document.fromJson(
        jsonDecode(snapshot.contentDocJson) as List<dynamic>,
      );

      expect(doc.toPlainText(), 'Legacy Title\n\nLine One\nLine Two\n');
      final ops = doc.toDelta().toJson();
      expect(ops[1]['attributes']?['header'], 1);
    });

    test(
      'fromDocJson maps legacy bulleted/numbered/todo/quote blocks to quill styles',
      () {
        final legacy = <String, dynamic>{
          'type': 'page',
          'children': [
            {
              'type': 'heading',
              'data': {
                'level': 1,
                'delta': [
                  {'insert': 'Title'},
                ],
              },
            },
            {
              'type': 'bulleted_list',
              'data': {
                'delta': [
                  {'insert': 'Bullet item'},
                ],
              },
            },
            {
              'type': 'numbered_list',
              'data': {
                'delta': [
                  {'insert': 'Number item'},
                ],
              },
            },
            {
              'type': 'todo_list',
              'data': {
                'checked': true,
                'delta': [
                  {'insert': 'Done item'},
                ],
              },
            },
            {
              'type': 'quote',
              'data': {
                'delta': [
                  {'insert': 'Quoted'},
                ],
              },
            },
          ],
        };

        final snapshot = NoteDocCodec.fromDocJson(
          docJson: jsonEncode(legacy),
          fallbackMarkdown: '# Fallback\n\nunused body',
        );
        final doc = quill.Document.fromJson(
          jsonDecode(snapshot.contentDocJson) as List<dynamic>,
        );
        final ops = doc.toDelta().toJson();

        final bulletBreak = ops.firstWhere(
          (op) => op['insert'] == '\n' && op['attributes']?['list'] == 'bullet',
          orElse: () => <String, dynamic>{},
        );
        final orderedBreak = ops.firstWhere(
          (op) =>
              op['insert'] == '\n' && op['attributes']?['list'] == 'ordered',
          orElse: () => <String, dynamic>{},
        );
        final checkedBreak = ops.firstWhere(
          (op) =>
              op['insert'] == '\n' && op['attributes']?['list'] == 'checked',
          orElse: () => <String, dynamic>{},
        );
        final quoteBreak = ops.firstWhere(
          (op) =>
              op['insert'] == '\n' && op['attributes']?['blockquote'] == true,
          orElse: () => <String, dynamic>{},
        );

        expect(bulletBreak.isNotEmpty, true);
        expect(orderedBreak.isNotEmpty, true);
        expect(checkedBreak.isNotEmpty, true);
        expect(quoteBreak.isNotEmpty, true);
      },
    );
  });
}
