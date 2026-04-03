import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_subject.dart';
import '../../request/bangumi/bangumi_api.dart';
import 'bangumi_remote_data_source.dart';

class BTBangumiRemoteDataSourceImpl implements BTBangumiRemoteDataSource {
  final BtrBangumiApi _api;

  BTBangumiRemoteDataSourceImpl({BtrBangumiApi? api})
    : _api = api ?? BtrBangumiApi();

  @override
  Future<BTResponse<List<BangumiCalendarRespData>>> getToday() async {
    var response = await _api.getToday();
    return BTResponse(
      code: response.code,
      message: response.message,
      data: response.data as List<BangumiCalendarRespData>?,
    );
  }

  @override
  Future<dynamic> searchSubjects(
    String keyword, {
    String sort = 'match',
    int offset = 0,
    int limit = 10,
    List<BangumiSubjectType> type = const [BangumiSubjectType.anime],
    List<String>? tag,
    List<String>? airdate,
    List<String>? rating,
    List<String>? rank,
    bool? nsfw,
  }) async {
    return await _api.searchSubjects(
      keyword,
      sort: sort,
      offset: offset,
      limit: limit,
      type: type,
      tag: tag,
      airdate: airdate,
      rating: rating,
      rank: rank,
      nsfw: nsfw,
    );
  }

  @override
  Future<BTResponse<BangumiSubject>> getSubjectDetail(String id) async {
    var response = await _api.getSubjectDetail(id);
    return BTResponse(
      code: response.code,
      message: response.message,
      data: response.data as BangumiSubject?,
    );
  }

  @override
  Future<BTResponse<List<BangumiSubjectRelation>>> getSubjectRelations(
    int id,
  ) async {
    var response = await _api.getSubjectRelations(id);
    return BTResponse(
      code: response.code,
      message: response.message,
      data: response.data as List<BangumiSubjectRelation>?,
    );
  }

  @override
  Future<BTResponse<BangumiPageT<BangumiEpisode>>> getEpisodeList(
    int id, {
    BangumiLegacyEpisodeType? type,
    int? limit,
    int? offset,
  }) async {
    var response = await _api.getEpisodeList(
      id,
      type: type,
      limit: limit,
      offset: offset,
    );
    return BTResponse(
      code: response.code,
      message: response.message,
      data: response.data as BangumiPageT<BangumiEpisode>?,
    );
  }

  @override
  Future<BTResponse<BangumiUser>> getUserInfo() async {
    var response = await _api.getUserInfo();
    return BTResponse(
      code: response.code,
      message: response.message,
      data: response.data as BangumiUser?,
    );
  }

  @override
  Future<BTResponse<BangumiPageT<BangumiUserSubjectCollection>>>
  getCollectionSubjects({
    String? username,
    BangumiSubjectType? subjectType,
    BangumiCollectionType? collectionType,
    int? limit,
    int? offset,
  }) async {
    var response = await _api.getCollectionSubjects(
      username: username ?? '-',
      subjectType: subjectType,
      collectionType: collectionType,
      limit: limit,
      offset: offset,
    );
    return BTResponse(
      code: response.code,
      message: response.message,
      data: response.data as BangumiPageT<BangumiUserSubjectCollection>?,
    );
  }

  @override
  Future<BTResponse<BangumiUserSubjectCollection>> getCollectionSubject(
    String username,
    int subjectId,
  ) async {
    var response = await _api.getCollectionSubject(username, subjectId);
    return BTResponse(
      code: response.code,
      message: response.message,
      data: response.data as BangumiUserSubjectCollection?,
    );
  }

  @override
  Future<BTResponse<void>> addCollectionSubject(int subjectId) async {
    var response = await _api.addCollectionSubject(subjectId);
    return BTResponse(
      code: response.code,
      message: response.message,
      data: null,
    );
  }

  @override
  Future<BTResponse<void>> updateCollectionSubject(
    int subjectId, {
    BangumiCollectionType? type,
    int? rate,
    int? ep,
    int? vol,
    String? comment,
    bool? private,
    List<String>? tags,
  }) async {
    var response = await _api.updateCollectionSubject(
      subjectId,
      type: type,
      rate: rate,
      ep: ep,
      vol: vol,
      comment: comment,
      private: private,
      tags: tags,
    );
    return BTResponse(
      code: response.code,
      message: response.message,
      data: null,
    );
  }

  @override
  Future<BTResponse<BangumiPageT<BangumiUserEpisodeCollection>>>
  getCollectionEpisodes(
    int subjectId, {
    int? offset,
    int? limit,
    BangumiLegacyEpisodeType? type,
  }) async {
    var response = await _api.getCollectionEpisodes(
      subjectId,
      offset: offset,
      limit: limit,
      type: type,
    );
    return BTResponse(
      code: response.code,
      message: response.message,
      data: response.data as BangumiPageT<BangumiUserEpisodeCollection>?,
    );
  }

  @override
  Future<BTResponse<BangumiUserEpisodeCollection>> getCollectionEpisode(
    int episodeId,
  ) async {
    var response = await _api.getCollectionEpisode(episodeId);
    return BTResponse(
      code: response.code,
      message: response.message,
      data: response.data as BangumiUserEpisodeCollection?,
    );
  }

  @override
  Future<BTResponse<void>> updateCollectionEpisode({
    required BangumiEpisodeCollectionType type,
    required int episode,
  }) async {
    var response = await _api.updateCollectionEpisode(
      type: type,
      episode: episode,
    );
    return BTResponse(
      code: response.code,
      message: response.message,
      data: null,
    );
  }
}
