import '../../models/database/app_bmf_model.dart';
import '../../tools/log_tool.dart';
import '../bt_sqlite.dart';

/// Bangumi-Mikan-File Map
/// 用于存储特定条目对应的MikanRSS及下载目录
class BtsAppBmf {
  BtsAppBmf._();

  /// 实例
  static final BtsAppBmf _instance = BtsAppBmf._();

  /// 获取实例
  factory BtsAppBmf() => _instance;

  /// 数据库
  final BTSqlite sqlite = BTSqlite();

  /// 表名
  final String _tableName = 'AppBmf';

  /// 前置检查
  Future<void> preCheck() async {
    var check = await _instance.sqlite.isTableExist(_instance._tableName);
    if (!check) {
      await _instance.sqlite.db.execute('''
        CREATE TABLE $_tableName (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          subject INTEGER NOT NULL,
          rss TEXT,
          download TEXT,
          UNIQUE(subject)
        );
      ''');
      BTLogTool.info('Create table $_tableName');
    }
  }

  /// 读取全部配置
  Future<List<AppBmfModel>> readAll() async {
    await _instance.preCheck();
    var result = await _instance.sqlite.db.query(_tableName);
    return result.map(AppBmfModel.fromJson).toList();
  }

  /// 读取配置
  Future<AppBmfModel?> read(int subject) async {
    await _instance.preCheck();
    var result = await _instance.sqlite.db.query(
      _tableName,
      where: 'subject = ?',
      whereArgs: [subject],
    );
    if (result.isEmpty) return null;
    var value = result.first;
    BTLogTool.info('Read $_tableName subject: $subject');
    return AppBmfModel.fromJson(value);
  }

  /// 写入/更新配置
  Future<void> write(AppBmfModel model) async {
    await _instance.preCheck();
    var result = await _instance.sqlite.db.query(
      _tableName,
      where: 'subject = ?',
      whereArgs: [model.subject],
    );
    // 因为这边有个自增ID, 所以不能直接 toJson及调用insert
    if (result.isEmpty) {
      await _instance.sqlite.db.rawInsert(
          'INSERT INTO $_tableName (subject, rss, download) VALUES (?, ?, ?)',
          [model.subject, model.rss, model.download]);
    } else {
      await _instance.sqlite.db.rawUpdate(
        'UPDATE $_tableName SET rss = ?, download = ? WHERE subject = ?',
        [model.rss, model.download, model.subject],
      );
    }
    BTLogTool.info('Write $_tableName subject: ${model.subject}');
  }

  /// 删除配置
  Future<void> delete(int subject) async {
    await _instance.preCheck();
    await _instance.sqlite.db.delete(
      _tableName,
      where: 'subject = ?',
      whereArgs: [subject],
    );
    BTLogTool.info('Delete $_tableName subject: $subject');
  }
}
