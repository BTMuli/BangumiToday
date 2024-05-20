// Project imports:
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../tools/log_tool.dart';
import '../bt_sqlite.dart';

/// 负责 bangumi.tv 用户收藏相关处理
/// 首先将用户所有收藏的条目信息存储到数据库中
/// 然后每次用户打开条目时，若用户收藏了该条目，则在打开条目时，更新数据库中的条目信息
/// 若用户未收藏该条目，当用户收藏该条目时，进行数据库的更新
class BtsBangumiCollection {
  BtsBangumiCollection._();

  /// 实例
  static final BtsBangumiCollection _instance = BtsBangumiCollection._();

  /// 获取实例
  factory BtsBangumiCollection() => _instance;

  /// 数据库
  final BTSqlite sqlite = BTSqlite();

  /// 表名
  final String _tableName = 'BangumiCollection';

  /// 初始化
  Future<void> init() async {
    var check = await _instance.sqlite.isTableExist(_tableName);
    if (!check) {
      await _instance.sqlite.db.execute('''
        CREATE TABLE $_tableName (
          subjectId INTEGER PRIMARY KEY,
          subjectType INTEGER NOT NULL,
          rate INTEGER NOT NULL,
          collectionType INTEGER NOT NULL,
          comment TEXT,
          tags TEXT NOT NULL,
          epStat INTEGER NOT NULL,
          volStat INTEGER NOT NULL,
          updatedAt TEXT NOT NULL,
          private INTEGER NOT NULL,
          subject TEXT
        );
      ''');
      BTLogTool.info('Create table $_tableName');
    } else {
      BTLogTool.warn('Table $_tableName already exists');
      await _instance.sqlite.db.execute('DROP TABLE $_tableName');
      BTLogTool.warn('Table $_tableName dropped');
      await _instance.init();
    }
  }

  /// 前置检查
  Future<void> preCheck() async {
    var check = await _instance.sqlite.isTableExist(_tableName);
    if (!check) {
      BTLogTool.warn('Table $_tableName not exists');
      await _instance.init();
    }
  }

  /// 获取全部收藏
  Future<List<BangumiUserSubjectCollection>> getAll() async {
    await _instance.preCheck();
    var resp = await _instance.sqlite.db.query(_tableName);
    return resp.map(BangumiUserSubjectCollection.fromSqlJson).toList();
  }

  /// 获取收藏数量
  Future<int> getCount() async {
    await _instance.preCheck();
    var resp = await _instance.sqlite.db.query(_tableName);
    return resp.length;
  }

  /// 获取指定收藏类型的收藏
  Future<List<BangumiUserSubjectCollection>> getByType(
    BangumiCollectionType type,
  ) async {
    await _instance.preCheck();
    var resp = await _instance.sqlite.db.query(
      _tableName,
      where: 'collectionType = ?',
      whereArgs: [type.value],
    );
    return resp.map(BangumiUserSubjectCollection.fromSqlJson).toList();
  }

  /// 搜索收藏
  Future<List<BangumiUserSubjectCollection>> search(
    String keyword, {
    bool check = true,
    BangumiCollectionType? type,
  }) async {
    if (check) {
      await _instance.preCheck();
    }
    if (type != null) {
      var resp = await _instance.sqlite.db.query(
        _tableName,
        where: 'subject LIKE ? AND collectionType = ?',
        whereArgs: ['%$keyword%', type.value],
      );
      return resp.map(BangumiUserSubjectCollection.fromSqlJson).toList();
    }
    var resp = await _instance.sqlite.db.query(
      _tableName,
      where: 'subject LIKE ?',
      whereArgs: ['%$keyword%'],
    );
    return resp.map(BangumiUserSubjectCollection.fromSqlJson).toList();
  }

  /// 判断是否在收藏列表中
  Future<bool> isCollected(int subjectId) async {
    await _instance.preCheck();
    var resp = await _instance.sqlite.db.query(
      _tableName,
      where: 'subjectId = ?',
      whereArgs: [subjectId],
    );
    return resp.isNotEmpty;
  }

  /// 读取收藏
  Future<BangumiUserSubjectCollection?> read(int subjectId) async {
    await _instance.preCheck();
    var resp = await _instance.sqlite.db.query(
      _tableName,
      where: 'subjectId = ?',
      whereArgs: [subjectId],
    );
    if (resp.isEmpty) {
      return null;
    }
    return BangumiUserSubjectCollection.fromSqlJson(resp.first);
  }

  /// 添加/更新收藏
  Future<void> write(
    BangumiUserSubjectCollection collection, {
    bool check = true,
  }) async {
    if (check) {
      await _instance.preCheck();
    }
    var checkT = await _instance.sqlite.db.query(
      _tableName,
      where: 'subjectId = ?',
      whereArgs: [collection.subjectId],
    );
    if (checkT.isEmpty) {
      await _instance.sqlite.db.insert(_tableName, collection.toSqlJson());
      BTLogTool.info('Add collection: ${collection.subjectId}');
    } else {
      await _instance.sqlite.db.update(
        _tableName,
        collection.toSqlJson(),
        where: 'subjectId = ?',
        whereArgs: [collection.subjectId],
      );
      BTLogTool.info('Update collection: ${collection.subjectId}');
    }
  }

  /// 写入/更新收藏列表
  Future<void> writeList(List<BangumiUserSubjectCollection> collections) async {
    await _instance.preCheck();
    for (var collection in collections) {
      await write(collection, check: false);
    }
  }

  /// 删除收藏
  Future<void> delete(int subjectId) async {
    await _instance.preCheck();
    await _instance.sqlite.db.delete(
      _tableName,
      where: 'subjectId = ?',
      whereArgs: [subjectId],
    );
    BTLogTool.info('Delete collection: $subjectId');
  }
}
