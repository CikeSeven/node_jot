import 'package:appflowy_editor/appflowy_editor.dart';

void main() {
  final codec = AppFlowyEditorMarkdownCodec();
  final doc = codec.decode('# 标题\n\n');
  final blank = Document.blank(withInitialText: true);
  print('decode children: ');
  print('decode json: ');
  print('blank children: ');
  print('blank json: ');
}
