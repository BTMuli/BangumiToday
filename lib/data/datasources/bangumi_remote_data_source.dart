// Project imports:
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/bangumi_subject_browse.dart';
import '../../models/bangumi/request_subject.dart';

abstract class BTBangumiRemoteDataSource {
  Future<BTResponse<List<BangumiCalendarRespData>>> getToday();

  Future<BTResponse<BangumiSubjectBrowsePage>> getSubjectBrowse({
    BangumiSubjectBrowseSort sort = BangumiSubjectBrowseSort.trends,
    int page = 1,
    int? year,
    int? month,
  });

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

  Future<BTResponse<BangumiPageT<BangumiSubjectReview>>> getSubjectReviews(
    int id, {
    int offset = 0,
    int limit = 20,
  });

  Future<BTResponse<BangumiReviewDetail>> getReviewDetail(int entryId);

  Future<BTResponse<List<BangumiEpisodeComment>>> getReviewComments(
    int entryId,
  );

  Future<BTResponse<BangumiPageT<BangumiEpisode>>> getEpisodeList(
    int id, {
    BangumiLegacyEpisodeType? type,
    int? limit,
    int? offset,
  });

  Future<BTResponse<BangumiEpisodeDetail>> getEpisodeDetail(int episodeId);

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
    bool Function()? authScope,
  });

  Future<BTResponse<BangumiUserSubjectCollection>> getCollectionSubject(
    String username,
    int subjectId, {
    bool fresh = false,
    bool Function()? authScope,
  });

  Future<BTResponse<void>> addCollectionSubject(
    int subjectId, {
    bool Function()? authScope,
  });

  Future<BTResponse<void>> updateCollectionSubject(
    int subjectId, {
    BangumiCollectionType? type,
    int? rate,
    int? ep,
    int? vol,
    String? comment,
    bool? private,
    List<String>? tags,
    bool Function()? authScope,
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
}
