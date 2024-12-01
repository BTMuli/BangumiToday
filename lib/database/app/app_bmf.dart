// Project imports:
import '../../models/database/app_bmf_model.dart';
import '../../tools/log_tool.dart';
import '../bt_sqlite.dart';

/// Bangumi-Mikan-File Map
/// 用于存储特定条目对应的MikanRSS及下载目录
class BtsAppBmf {
  BtsAppBmf._();

  /// 实例
  static final BtsAppBmf _instance = BtsAppBmf._();

  /// 是否有title字段
  static bool hasTitle = false;

  /// 是否有mk字段
  static bool hasMk = false;

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
          title TEXT DEFAULT '',
          rss TEXT,
          download TEXT,
          UNIQUE(subject)
        );
      ''');
      BTLogTool.info('Create table $_tableName');
      hasTitle = true;
    }

    /// 为了兼容旧版本，这里需要检查是否有title字段
    if (!hasTitle) await checkUpdate();

    /// 为了兼容旧版本，这里需要检查是否有mk字段
    if (!hasMk) await checkMkUpdate();
  }

  /// 检查是否有title字段
  Future<void> checkUpdate() async {
    var check = await _instance.sqlite.db.rawQuery(
      'PRAGMA table_info($_tableName)',
    );
    hasTitle = check.any((element) => element['name'] == 'title');
    if (!hasTitle) {
      await _instance.sqlite.db.execute('''
        ALTER TABLE $_tableName ADD COLUMN title TEXT DEFAULT '';
      ''');
      BTLogTool.info('Update table $_tableName add title');
    }
  }

  /// 检查是否有mk字段
  Future<void> checkMkUpdate() async {
    var check = await _instance.sqlite.db.rawQuery(
      'PRAGMA table_info($_tableName)',
    );
    hasMk = check.any((element) => element['name'] == 'mkBgmId');
    if (!hasMk) {
      await _instance.sqlite.db.execute('''
        ALTER TABLE $_tableName ADD COLUMN mkBgmId TEXT DEFAULT '';
        ALTER TABLE $_tableName ADD COLUMN mkGroupId TEXT DEFAULT '';
      ''');
      BTLogTool.info('Update table $_tableName add mk');
    }
  }

  /// 读取全部配置
  Future<List<AppBmfModel>> readAll() async {
    await _instance.preCheck();
    var result = await _instance.sqlite.db.query(_tableName);
    if (result.isEmpty) return [];
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
    return AppBmfModel.fromJson(value);
  }

  /// 写入/更新配置
  Future<void> write(AppBmfModel model) async {
    await _instance.preCheck();
    if (model.rss != null && model.rss!.isNotEmpty) {
      var url = Uri.parse(model.rss!);
      model.mkBgmId ??= url.queryParameters['bangumiId'];
      model.mkGroupId ??= url.queryParameters['subgroupid'];
    }
    var result = await _instance.sqlite.db.query(
      _tableName,
      where: 'subject = ?',
      whereArgs: [model.subject],
    );
    // 因为这边有个自增ID, 所以不能直接 toJson及调用insert
    if (result.isEmpty) {
      await _instance.sqlite.db.rawInsert(
          'INSERT INTO $_tableName '
          '(subject, rss, download,title, mkBgmId, mkGroupId) '
          'VALUES (?, ?, ?, ?)',
          [
            model.subject,
            model.rss,
            model.download,
            model.title,
            model.mkBgmId,
            model.mkGroupId
          ]);
    } else {
      await _instance.sqlite.db.rawUpdate(
        'UPDATE $_tableName SET '
        'rss = ?, download = ?, title = ?, mkBgmId = ?, mkGroupId = ? '
        'WHERE subject = ?',
        [
          model.rss,
          model.download,
          model.title,
          model.mkBgmId,
          model.mkGroupId,
          model.subject,
        ],
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

  /// 检测RSS链接是否存在
  Future<bool> checkRss(String input) async {
    var res = await _instance.sqlite.db.query(
      _tableName,
      where: 'rss = ?',
      whereArgs: [input],
    );
    return res.isNotEmpty;
  }

  /// 检测下载目录是否存在
  Future<bool> checkDir(String dir) async {
    var res = await _instance.sqlite.db.query(
      _tableName,
      where: 'download = ?',
      whereArgs: [dir],
    );
    return res.isNotEmpty;
  }

  /// 更新MikanRSS链接
  Future<void> updateMikanUrl(String url, String ori) async {
    var resAll = await readAll();
    for (var item in resAll) {
      if (item.rss != null &&
          item.rss!.isNotEmpty &&
          item.rss!.startsWith(ori)) {
        var newRss = item.rss!.replaceFirst(ori, url);
        await write(
          AppBmfModel(
            subject: item.subject,
            rss: newRss,
            download: item.download,
            title: item.title,
          ),
        );
      }
    }
  }
}
