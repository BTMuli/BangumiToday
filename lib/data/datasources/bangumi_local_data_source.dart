// Project imports:
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';

abstract class BTBangumiLocalDataSource {
  Future<void> init();

  Future<List<BangumiUserSubjectCollection>> getCollections();

  Future<List<BangumiUserSubjectCollection>> getByType(
    BangumiCollectionType type,
  );

  Future<Set<int>> getAllSubjectIds();

  Future<BangumiUserSubjectCollection?> getCollection(int subjectId);

  Future<void> insertCollection(BangumiUserSubjectCollection collection);

  Future<void> updateCollection(BangumiUserSubjectCollection collection);

  Future<void> writeList(List<BangumiUserSubjectCollection> collections);

  Future<void> deleteCollection(int subjectId);

  Future<bool> isCollected(int subjectId);

  Future<void> clearAll();
}
