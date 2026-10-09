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
  BtDatabase? _database;

  BtDatabase get db => _database ?? (throw StateError('SQLite 连接尚未打开或已经关闭'));

  static bool _isInitialized = false;
  static Future<void>? _initFuture;
  static Future<void>? _closeFuture;
  static bool _closing = false;

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
    if (_closing) return Future.error(StateError('SQLite 正在关闭'));
    if (_isInitialized) {
      return Future.value();
    }
    return _initFuture ??= _open().whenComplete(() {
      if (!_isInitialized) _initFuture = null;
    });
  }

  static Future<void> _open() async {
    var dbPath = await getDbPath();
    var database = BtDatabase.open(dbPath, onMigration: BTLogTool.info);
    // Drift 在首个查询时才真正打开连接并执行 `migration.beforeOpen`
    // （逐表补列）。先跑一次空查询，把结构补齐挡在业务读写之前。
    try {
      await database.customSelect('SELECT 1').get();
    } catch (error, stackTrace) {
      // A failed lazy open still owns an executor/isolate. Release it before
      // clearing the initialization future, so retries do not leak connections.
      try {
        await database.close();
      } catch (closeError) {
        BTLogTool.warn('关闭失败的数据库连接：$closeError');
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    _instance._database = database;
    _isInitialized = true;
    BTLogTool.info('SQLite init success');
    BTLogTool.info('Database path: $dbPath');
  }

  /// Drain Drift's executor and statement cache before its isolate is torn
  /// down. Do not leave sqlite3 native finalizers to race isolate shutdown.
  static Future<void> close() => _closeFuture ??= _close();

  static Future<void> _close() async {
    _closing = true;
    try {
      await _initFuture;
    } catch (_) {
      // Failed opens already close their executor before reporting failure.
    }
    var database = _instance._database;
    _instance._database = null;
    _isInitialized = false;
    _initFuture = null;
    await database?.close();
    BTLogTool.info('SQLite 已完成关闭');
  }
}
