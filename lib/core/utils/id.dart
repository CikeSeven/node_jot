import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 生成新的全局唯一业务 ID（UUID v4）。
String newUuid() {
  return _uuid.v4();
}
