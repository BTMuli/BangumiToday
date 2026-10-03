// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../core/services/file_service.dart';
import '../tools/log_tool.dart';
import 'drift/bt_database.dart';

/// SQLite 数据库
///
/// 应用只从这里拿连接：建表、补列与后续的版本迁移全部由
/// `BtDatabase.migration` 拥有，各个访问器不再自己探测表结构。
class BTSqlite {
  BTSqlite._();

  /// 实例
  static final BTSqlite _instance = BTSqlite._();

  /// 数据库
  late BtDatabase db;

  static bool _isInitialized = false;
  static Future<void>? _initFuture;

  /// 获取实例
  factory BTSqlite() => _instance;

  /// 已完成初始化且连接可用。
  static bool get isInitialized => _isInitialized;

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
    if (_isInitialized) {
      return Future.value();
    }
    return _initFuture ??= _open().whenComplete(() {
      if (!_isInitialized) _initFuture = null;
    });
  }

  static Future<void> _open() async {
    var dbPath = await getDbPath();
    _instance.db = BtDatabase.open(dbPath);
    // Drift 在首个查询时才真正打开连接并执行 `migration.beforeOpen`
    // （逐表补列）。先跑一次空查询，把结构补齐挡在业务读写之前。
    await _instance.db.customSelect('SELECT 1').get();
    _isInitialized = true;
    BTLogTool.info('SQLite init success');
    BTLogTool.info('Database path: $dbPath');
  }
}
