// Package imports:
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:
import '../tools/file_tool.dart';
import '../tools/log_tool.dart';

/// SQLite 数据库
class BTSqlite {
  BTSqlite._();

  /// 实例
  static final BTSqlite _instance = BTSqlite._();

  /// 数据库
  late Database db;

  static bool _isInitialized = false;
  static Future<void>? _initFuture;

  /// 获取实例
  factory BTSqlite() => _instance;

  /// 已完成初始化且连接可用（含测试注入的已打开数据库）。
  static bool get isInitialized {
    if (_isInitialized) return true;
    try {
      return _instance.db.isOpen;
    } catch (_) {
      return false;
    }
  }

  /// 获取数据库路径
  static Future<String> getDbPath() async {
    var fileTool = BTFileTool();
    var dir = await fileTool.getAppDataDir();
    var dbPath = path.join(dir, 'app', 'BangumiToday.db');
    if (!await fileTool.isFileExist(dbPath)) {
      await fileTool.createFile(dbPath);
    }
    return dbPath;
  }

  /// 初始化
  static Future<void> init() {
    if (isInitialized) {
      _isInitialized = true;
      return Future.value();
    }
    return _initFuture ??= _open().whenComplete(() {
      if (!_isInitialized) _initFuture = null;
    });
  }

  static Future<void> _open() async {
    var ffi = databaseFactoryFfi;
    sqfliteFfiInit();
    var path = await getDbPath();
    _instance.db = await ffi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1),
    );
    _isInitialized = true;
    BTLogTool.info('SQLite init success');
    BTLogTool.info('Database path: $path');
  }

  /// 检测表是否存在
  Future<bool> isTableExist(String table) async {
    var sql =
        '''
      SELECT COUNT(*) AS count
      FROM sqlite_master
      WHERE type='table' AND name='$table';
    ''';
    var result = await _instance.db.rawQuery(sql);
    var exist = result.first['count'] == 1;
    return exist;
  }

  /// 删除表
  Future<void> dropTable(String table) async {
    BTLogTool.info('Drop table: $table');
    await _instance.db.execute('DROP TABLE IF EXISTS $table;');
  }
}
