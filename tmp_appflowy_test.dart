import 'package:appflowy_editor/appflowy_editor.dart';

void main() {
  const md = '# 旧标题\n\n这是正文内容\n第二行';
  final codec = AppFlowyEditorMarkdownCodec();
  final doc = codec.decode(md);
  final encoded = codec.encode(doc);
  print('---encoded---');
  print(encoded);
  print('---doc-json---');
  print(doc.toJson());
}
