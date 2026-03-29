import '../../models/bangumi/bangumi_model.dart';

abstract class BTBangumiLocalDataSource {
  Future<void> init();

  Future<List<BangumiUserSubjectCollection>> getCollections();

  Future<BangumiUserSubjectCollection?> getCollection(int subjectId);

  Future<void> insertCollection(BangumiUserSubjectCollection collection);

  Future<void> updateCollection(BangumiUserSubjectCollection collection);

  Future<void> deleteCollection(int subjectId);

  Future<bool> isCollected(int subjectId);

  Future<void> clearAll();
}
