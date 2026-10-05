// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../tools/log_tool.dart';
import '../bt_sqlite.dart';
import '../drift/bt_database.dart';
import '../drift/collection_storage.dart';

/// 负责 bangumi.tv 用户收藏相关处理
/// 首先将用户所有收藏的条目信息存储到数据库中
/// 然后每次用户打开条目时，若用户收藏了该条目，则在打开条目时，更新数据库中的条目信息
/// 若用户未收藏该条目，当用户收藏该条目时，进行数据库的更新
///
/// 建表与补列由 `BtDatabase` 拥有，这里只做表存取。
class BtsBangumiCollection {
  BtsBangumiCollection._();

  /// 实例
  static final BtsBangumiCollection _instance = BtsBangumiCollection._();

  /// 获取实例
  factory BtsBangumiCollection() => _instance;

  /// 数据库
  BtDatabase get _db => BTSqlite().db;

  /// 获取全部收藏
  Future<List<BangumiUserSubjectCollection>> getAll() async {
    var rows = await _db.select(_db.bangumiCollection).get();
    return rows.map(_fromRow).toList();
  }

  /// 获取全部收藏条目 ID
  Future<Set<int>> getAllSubjectIds() async {
    var subjectId = _db.bangumiCollection.subjectId;
    var query = _db.selectOnly(_db.bangumiCollection)..addColumns([subjectId]);
    var rows = await query.get();
    return rows.map((row) => row.read(subjectId)).whereType<int>().toSet();
  }

  /// 获取收藏数量
  Future<int> getCount() {
    return _db.bangumiCollection.count().getSingle();
  }

  /// 获取指定收藏类型的收藏
  Future<List<BangumiUserSubjectCollection>> getByType(
    BangumiCollectionType type,
  ) async {
    var query = _db.select(_db.bangumiCollection)
      ..where((table) => table.collectionType.equals(type.value));
    var rows = await query.get();
    return rows.map(_fromRow).toList();
  }

  /// 搜索收藏
  Future<List<BangumiUserSubjectCollection>> search(
    String keyword, {
    BangumiCollectionType? type,
  }) async {
    var rows = await CollectionStorage(_db).search(keyword, type: type?.value);
    return rows.map(_fromRow).toList();
  }

  /// 判断是否在收藏列表中
  Future<bool> isCollected(int subjectId) async {
    var row = await _firstById(subjectId);
    return row != null;
  }

  /// 读取收藏
  Future<BangumiUserSubjectCollection?> read(int subjectId) async {
    var row = await _firstById(subjectId);
    if (row == null) {
      return null;
    }
    return _fromRow(row);
  }

  /// 添加/更新收藏
  Future<void> write(BangumiUserSubjectCollection collection) async {
    await CollectionStorage(_db).saveAll([_companion(collection)]);
    BTLogTool.info('Write collection: ${collection.subjectId}');
  }

  /// 写入/更新收藏列表
  Future<void> writeList(List<BangumiUserSubjectCollection> collections) async {
    await CollectionStorage(_db).saveAll(collections.map(_companion));
    BTLogTool.info('Write ${collections.length} collections');
  }

  /// 删除收藏
  Future<void> delete(int subjectId) async {
    var delete = _db.delete(_db.bangumiCollection)
      ..where((table) => table.subjectId.equals(subjectId));
    await delete.go();
    BTLogTool.info('Delete collection: $subjectId');
  }

  Future<CollectionRow?> _firstById(int subjectId) {
    var query = _db.select(_db.bangumiCollection)
      ..where((table) => table.subjectId.equals(subjectId));
    return query.getSingleOrNull();
  }

  BangumiUserSubjectCollection _fromRow(CollectionRow row) {
    return BangumiUserSubjectCollection.fromSqlJson(row.toJson());
  }

  BangumiCollectionCompanion _companion(
    BangumiUserSubjectCollection collection,
  ) {
    var values = collection.toSqlJson();
    return BangumiCollectionCompanion(
      subjectId: Value(values['subjectId'] as int),
      subjectType: Value(values['subjectType'] as int),
      rate: Value(values['rate'] as int),
      collectionType: Value(values['collectionType'] as int),
      comment: Value(values['comment'] as String?),
      tags: Value(values['tags'] as String),
      epStat: Value(values['epStat'] as int),
      volStat: Value(values['volStat'] as int),
      updatedAt: Value(values['updatedAt'] as String),
      private: Value(values['private'] as int),
      subject: Value(values['subject'] as String),
    );
  }
}
