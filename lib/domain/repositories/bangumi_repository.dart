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

  Future<BTResponse<BangumiPageT<BangumiEpisode>>> getEpisodeList(
    int id, {
    BangumiLegacyEpisodeType? type,
    int? limit,
    int? offset,
  });

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
  });
}
