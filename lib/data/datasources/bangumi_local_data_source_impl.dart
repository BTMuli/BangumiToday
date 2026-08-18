// Project imports:
import '../../database/bangumi/bangumi_collection.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import 'bangumi_local_data_source.dart';

class BTBangumiLocalDataSourceImpl implements BTBangumiLocalDataSource {
  final BtsBangumiCollection _db;

  BTBangumiLocalDataSourceImpl({BtsBangumiCollection? db})
    : _db = db ?? BtsBangumiCollection();

  @override
  Future<void> init() async {
    await _db.preCheck();
  }

  @override
  Future<List<BangumiUserSubjectCollection>> getCollections() async {
    return await _db.getAll();
  }

  @override
  Future<List<BangumiUserSubjectCollection>> getByType(
    BangumiCollectionType type,
  ) async {
    return await _db.getByType(type);
  }

  @override
  Future<Set<int>> getAllSubjectIds() async {
    return await _db.getAllSubjectIds();
  }

  @override
  Future<BangumiUserSubjectCollection?> getCollection(int subjectId) async {
    return await _db.read(subjectId);
  }

  @override
  Future<void> insertCollection(BangumiUserSubjectCollection collection) async {
    await _db.write(collection);
  }

  @override
  Future<void> updateCollection(BangumiUserSubjectCollection collection) async {
    await _db.write(collection);
  }

  @override
  Future<void> writeList(List<BangumiUserSubjectCollection> collections) async {
    await _db.writeList(collections);
  }

  @override
  Future<void> deleteCollection(int subjectId) async {
    await _db.delete(subjectId);
  }

  @override
  Future<bool> isCollected(int subjectId) async {
    return await _db.isCollected(subjectId);
  }

  @override
  Future<void> clearAll() async {
    var collections = await _db.getAll();
    for (var c in collections) {
      await _db.delete(c.subjectId);
    }
  }
}
