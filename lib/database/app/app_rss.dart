// Project imports:
import '../../models/database/app_rss_model.dart';
import '../../tools/log_tool.dart';
import '../bt_sqlite.dart';

/// AppRss 表，用于检测RSS订阅更新
/// 目前采取的是存储 RSS URL-RSS资源链接-获取时间 的方式
/// 通过比对获取时间来判断是否需要更新
class BtsAppRss {
  BtsAppRss._();

  /// 实例
  static final BtsAppRss instance = BtsAppRss._();

  /// 获取实例
  factory BtsAppRss() => instance;

  /// 数据库
  final BTSqlite sqlite = BTSqlite();

  /// 表名
  final String _tableName = 'AppRss';

  /// 前置检查
  Future<void> preCheck() async {
    var check = await instance.sqlite.isTableExist(instance._tableName);
    if (!check) {
      await instance.sqlite.db.execute('''
        CREATE TABLE $_tableName (
          rss TEXT PRIMARY KEY NOT NULL,
          data TEXT,
          ttl INTEGER NOT NULL,
          updated INTEGER NOT NULL
        );
      ''');
      BTLogTool.info('Create table $_tableName');
    }
  }

  /// 读取所有 rss 链接
  Future<List<String>> readAllRss() async {
    await instance.preCheck();
    var result = await instance.sqlite.db.query(_tableName);
    return result.map((e) => e['rss'] as String).toList();
  }

  /// 读取配置
  Future<AppRssModel?> read(String rss) async {
    await instance.preCheck();
    var result = await instance.sqlite.db.query(
      _tableName,
      where: 'rss = ?',
      whereArgs: [rss],
    );
    if (result.isEmpty) return null;
    var value = result.first;
    return AppRssModel.fromJson(value);
  }

  /// 写入/更新配置
  Future<void> write(AppRssModel model) async {
    await instance.preCheck();
    model.updated = DateTime.now().millisecondsSinceEpoch;
    var check = await instance.sqlite.db.query(
      _tableName,
      where: 'rss = ?',
      whereArgs: [model.rss],
    );
    if (check.isEmpty) {
      await instance.sqlite.db.insert(
        _tableName,
        model.toJson(),
      );
    } else {
      await instance.sqlite.db.update(
        _tableName,
        model.toJson(),
        where: 'rss = ?',
        whereArgs: [model.rss],
      );
    }
  }

  /// 删除配置
  Future<void> delete(String rss) async {
    await instance.preCheck();
    await instance.sqlite.db.delete(
      _tableName,
      where: 'rss = ?',
      whereArgs: [rss],
    );
  }
}
