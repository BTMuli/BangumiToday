// Project imports:
import '../../models/database/app_rss_model.dart';
import '../../tools/log_tool.dart';
import '../bt_sqlite.dart';
import 'app_bmf.dart';

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

  /// BMF 数据库
  final BtsAppBmf bmf = BtsAppBmf();

  /// 是否有mkBgmId
  static bool hasMkBgmId = false;

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
          mkBgmId TEXT,
          mkGroupId TEXT,
          ttl INTEGER NOT NULL,
          updated INTEGER NOT NULL
        );
      ''');
      BTLogTool.info('Create table $_tableName');
    }
    if (!hasMkBgmId) await updateMkId();
  }

  /// 更新mkId
  Future<void> updateMkId() async {
    var check = await instance.sqlite.db.rawQuery(
      'PRAGMA table_info($_tableName)',
    );
    hasMkBgmId = check.any((element) => element['name'] == 'mkBgmId');
    if (hasMkBgmId) return;
    await instance.sqlite.db.execute('''
      ALTER TABLE $_tableName ADD COLUMN mkBgmId TEXT;
      ALTER TABLE $_tableName ADD COLUMN mkGroupId TEXT;
    ''');
    BTLogTool.info('Update table $_tableName');
  }

  /// 读取所有 rss 链接
  Future<List<AppRssModel>> readAll() async {
    await instance.preCheck();
    var result = await instance.sqlite.db.query(_tableName);
    if (result.isEmpty) return [];
    return result.map(AppRssModel.fromJson).toList();
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
    if (model.mkBgmId != null) {
      await writeByMkId(model);
      return;
    }
    var check = await instance.sqlite.db.query(
      _tableName,
      where: 'rss = ?',
      whereArgs: [model.rss],
    );
    if (check.isEmpty) {
      await instance.sqlite.db.insert(_tableName, model.toJson());
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

  /// 更新 Mikan URL
  Future<void> updateMikanUrl(String url, String ori) async {
    await instance.preCheck();
    await bmf.updateMikanUrl(url, ori);
  }

  /// 删除 Mikan URL
  Future<void> deleteByMkId(String s) async {
    await instance.preCheck();
    await instance.sqlite.db.delete(
      _tableName,
      where: 'mkBgmId = ?',
      whereArgs: [s],
    );
  }

  /// 读取 Mikan URL
  Future<AppRssModel?> readByMkId(String s) async {
    await instance.preCheck();
    var result = await instance.sqlite.db.query(
      _tableName,
      where: 'mkBgmId = ?',
      whereArgs: [s],
    );
    if (result.isEmpty) return null;
    var value = result.first;
    return AppRssModel.fromJson(value);
  }

  /// 写入/更新配置
  Future<void> writeByMkId(AppRssModel model) async {
    await instance.preCheck();
    model.updated = DateTime.now().millisecondsSinceEpoch;
    var check = await instance.sqlite.db.query(
      _tableName,
      where: 'mkBgmId = ?',
      whereArgs: [model.mkBgmId],
    );
    // 检测是否有rss重复
    var rssCheck = await instance.sqlite.db.query(
      _tableName,
      where: 'rss = ?',
      whereArgs: [model.rss],
    );
    if (rssCheck.isNotEmpty) {
      // 如果有重复的，检测是否是同一个mkId
      var rssValue = rssCheck.first;
      if (rssValue['mkBgmId'] != model.mkBgmId) {
        await instance.sqlite.db.delete(
          _tableName,
          where: 'rss = ?',
          whereArgs: [model.rss],
        );
      } else {
        // 如果是同一个mkId，更新数据
        await instance.sqlite.db.update(
          _tableName,
          model.toJson(),
          where: 'rss = ?',
          whereArgs: [model.rss],
        );
      }
    } else if (check.isEmpty) {
      await instance.sqlite.db.insert(_tableName, model.toJson());
    } else {
      await instance.sqlite.db.update(
        _tableName,
        model.toJson(),
        where: 'mkBgmId = ?',
        whereArgs: [model.mkBgmId],
      );
    }
  }
}
