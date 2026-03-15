import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart' as quill_delta;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_jot/features/notes/editor/markdown_auto_formatter.dart';

void main() {
  group('MarkdownAutoFormatter', () {
    late MarkdownAutoFormatter formatter;

    setUp(() {
      formatter = MarkdownAutoFormatter();
    });

    test('converts # + space to heading 1 block', () {
      final controller = _newController();

      _typeAndFormat(controller, formatter, '#');
      _typeAndFormat(controller, formatter, ' ');

      final ops = controller.document.toDelta().toJson();
      expect(controller.document.toPlainText(), '\n');
      expect(ops.first['attributes']['header'], 1);
    });

    test('keeps heading style on previous line after pressing enter', () {
      final controller = _newController();

      _typeAndFormat(controller, formatter, '# ');
      _typeAndFormat(controller, formatter, 'ab');
      _typeAndFormat(controller, formatter, '\n');

      expect(controller.document.toPlainText(), 'ab\n\n');
      final ops = controller.document.toDelta().toJson();
      expect(ops[1]['insert'], '\n');
      expect(ops[1]['attributes']?['header'], 1);
      expect(ops[2]['insert'], '\n');
      expect(ops[2]['attributes'], isNull);
    });

    test('repairs heading style drift to next empty line on enter', () {
      final document = quill.Document.fromDelta(
        quill_delta.Delta()
          ..insert('title\n')
          ..insert('\n', {'header': 1}),
      );
      final controller = quill.QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 6),
      );

      final changed = formatter.applyIfNeeded(
        controller: controller,
        change: quill.DocChange(
          quill_delta.Delta(),
          quill_delta.Delta()..insert('\n'),
          quill.ChangeSource.local,
        ),
      );

      expect(changed, true);
      final ops = controller.document.toDelta().toJson();
      expect(ops[1]['insert'], '\n');
      expect(ops[1]['attributes']?['header'], 1);
      expect(ops[2]['insert'], '\n');
      expect(ops[2]['attributes'], isNull);
    });

    test('converts unordered list and checklist markers', () {
      final listController = _newController();
      _typeAndFormat(listController, formatter, '- ');
      final listOps = listController.document.toDelta().toJson();
      expect(listOps.first['attributes']['list'], 'bullet');

      final checkController = _newController();
      _typeAndFormat(checkController, formatter, '- [x] ');
      final checkOps = checkController.document.toDelta().toJson();
      expect(checkOps.first['attributes']['list'], 'checked');
    });

    test('converts **bold** to inline bold style', () {
      final controller = _newController('Hi ');

      _typeAndFormat(controller, formatter, '**abc**');

      expect(controller.document.toPlainText(), 'Hi abc\n');
      final ops = controller.document.toDelta().toJson();
      final boldOp = ops.firstWhere(
        (op) => op['insert'] == 'abc',
        orElse: () => <String, dynamic>{},
      );
      expect(boldOp['attributes']['bold'], true);
    });

    test('converts *italic* and `code` inline styles', () {
      final italicController = _newController('A ');
      _typeAndFormat(italicController, formatter, '*x*');
      final italicOps = italicController.document.toDelta().toJson();
      final italicOp = italicOps.firstWhere(
        (op) => op['insert'] == 'x',
        orElse: () => <String, dynamic>{},
      );
      expect(italicOp['attributes']['italic'], true);

      final codeController = _newController('B ');
      _typeAndFormat(codeController, formatter, '`y`');
      final codeOps = codeController.document.toDelta().toJson();
      final codeOp = codeOps.firstWhere(
        (op) => op['insert'] == 'y',
        orElse: () => <String, dynamic>{},
      );
      expect(codeOp['attributes']['code'], true);
    });

    test('ignores non-local changes', () {
      final controller = _newController();
      controller.replaceText(
        0,
        0,
        '# ',
        const TextSelection.collapsed(offset: 2),
      );

      final changed = formatter.applyIfNeeded(
        controller: controller,
        change: quill.DocChange(
          quill_delta.Delta(),
          quill_delta.Delta()..insert('# '),
          quill.ChangeSource.remote,
        ),
      );

      expect(changed, false);
      expect(controller.document.toPlainText(), '# \n');
    });
  });
}

quill.QuillController _newController([String initialText = '']) {
  final document = quill.Document.fromDelta(
    quill_delta.Delta()..insert('$initialText\n'),
  );
  return quill.QuillController(
    document: document,
    selection: TextSelection.collapsed(offset: initialText.length),
  );
}

void _typeAndFormat(
  quill.QuillController controller,
  MarkdownAutoFormatter formatter,
  String text,
) {
  final offset = controller.selection.baseOffset;
  controller.replaceText(
    offset,
    0,
    text,
    TextSelection.collapsed(offset: offset + text.length),
  );

  formatter.applyIfNeeded(
    controller: controller,
    change: quill.DocChange(
      quill_delta.Delta(),
      quill_delta.Delta()..insert(text),
      quill.ChangeSource.local,
    ),
  );
}
