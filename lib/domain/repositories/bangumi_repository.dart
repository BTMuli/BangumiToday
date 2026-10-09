// Project imports:
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_subject.dart';

abstract class BTBangumiRepository {
  Future<BTResponse<List<BangumiCalendarRespData>>> getToday();

  Future<dynamic> searchSubjects(
    String keyword, {
    String sort,
    int offset,
    int limit,
    List<BangumiSubjectType> type,
    List<String>? tag,
    List<String>? airdate,
    List<String>? rating,
    List<String>? rank,
    bool? nsfw,
  });

  Future<BTResponse<BangumiSubject>> getSubjectDetail(String id);

  Future<BTResponse<List<BangumiSubjectRelation>>> getSubjectRelations(int id);

  Future<BTResponse<List<BangumiRelatedCharacter>>> getSubjectCharacters(
    int id,
  );

  Future<BTResponse<List<BangumiRelatedPerson>>> getSubjectPersons(int id);

  Future<BTResponse<BangumiPageT<BangumiSubjectComment>>> getSubjectComments(
    int id, {
    BangumiCollectionType? type,
    int offset = 0,
    int limit = 20,
  });

  Future<BTResponse<BangumiPageT<BangumiEpisode>>> getEpisodeList(
    int id, {
    BangumiLegacyEpisodeType? type,
    int? limit,
    int? offset,
  });

  /// 清除条目的共享章节分页，供显式刷新和分页变化后的重试使用。
  void invalidateEpisodeList(int subject);

  /// 单章节详情，含所属条目摘要与当前用户收藏状态。
  Future<BTResponse<BangumiEpisodeDetail>> getEpisodeDetail(int episodeId);

  /// 单章节吐槽箱，一次返回全部顶层吐槽及其回复。
  Future<BTResponse<List<BangumiEpisodeComment>>> getEpisodeComments(
    int episodeId,
  );

  Future<BTResponse<BangumiUser>> getUserInfo();

  Future<BTResponse<BangumiPageT<BangumiUserSubjectCollection>>>
  getCollectionSubjects({
    String? username,
    BangumiSubjectType? subjectType,
    BangumiCollectionType? collectionType,
    int? limit,
    int? offset,
  });

  Future<BTResponse<BangumiUserSubjectCollection>> getCollectionSubject(
    String username,
    int subjectId,
  );

  Future<BTResponse<void>> addCollectionSubject(int subjectId);

  Future<BTResponse<void>> updateCollectionSubject(
    int subjectId, {
    BangumiCollectionType? type,
    int? rate,
    int? ep,
    int? vol,
    String? comment,
    bool? private,
    List<String>? tags,
  });

  Future<BTResponse<BangumiPageT<BangumiUserEpisodeCollection>>>
  getCollectionEpisodes(
    int subjectId, {
    int? offset,
    int? limit,
    BangumiLegacyEpisodeType? type,
  });

  Future<BTResponse<BangumiUserEpisodeCollection>> getCollectionEpisode(
    int episodeId,
  );

  Future<BTResponse<void>> updateCollectionEpisode({
    required BangumiEpisodeCollectionType type,
    required int episode,
    bool Function()? authScope,
  });

  /// 本地收藏条目 ID，供日历筛选。
  Future<Set<int>> getCollectedSubjectIds();

  /// 本地收藏列表，供收藏 Tab 首屏。
  Future<List<BangumiUserSubjectCollection>> getLocalCollections({
    BangumiCollectionType? type,
  });

  /// 本地单条收藏，供条目详情首屏。
  Future<BangumiUserSubjectCollection?> getLocalCollection(int subjectId);
}
