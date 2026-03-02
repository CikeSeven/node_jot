import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'collections/device_entity.dart';
import 'collections/note_entity.dart';
import 'collections/op_log_entity.dart';
import 'collections/sync_cursor_entity.dart';

/// Isar 数据库生命周期管理。
class IsarService {
  IsarService._(this.db);

  final Isar db;

  /// 打开本地 Isar 实例并注册所有集合 Schema。
  static Future<IsarService> open() async {
    final dir = await getApplicationSupportDirectory();
    final isar = await Isar.open(
      [
        NoteEntitySchema,
        DeviceEntitySchema,
        OpLogEntitySchema,
        SyncCursorEntitySchema,
      ],
      name: 'nodejot',
      directory: dir.path,
      inspector: false,
    );
    return IsarService._(isar);
  }

  /// 关闭数据库连接。
  Future<void> dispose() async {
    await db.close();
  }
}
