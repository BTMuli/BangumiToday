import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_subject.dart';
import '../datasources/bangumi_remote_data_source.dart';
import '../../domain/repositories/bangumi_repository.dart';

class BTBangumiRepositoryImpl implements BTBangumiRepository {
  final BTBangumiRemoteDataSource _remoteDataSource;

  BTBangumiRepositoryImpl({required BTBangumiRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  @override
  Future<BTResponse<List<BangumiCalendarRespData>>> getToday() async {
    return await _remoteDataSource.getToday();
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
    return await _remoteDataSource.searchSubjects(
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
    return await _remoteDataSource.getSubjectDetail(id);
  }

  @override
  Future<BTResponse<List<BangumiSubjectRelation>>> getSubjectRelations(
    int id,
  ) async {
    return await _remoteDataSource.getSubjectRelations(id);
  }

  @override
  Future<BTResponse<BangumiPageT<BangumiEpisode>>> getEpisodeList(
    int id, {
    BangumiLegacyEpisodeType? type,
    int? limit,
    int? offset,
  }) async {
    return await _remoteDataSource.getEpisodeList(
      id,
      type: type,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<BTResponse<BangumiUser>> getUserInfo() async {
    return await _remoteDataSource.getUserInfo();
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
    return await _remoteDataSource.getCollectionSubjects(
      username: username,
      subjectType: subjectType,
      collectionType: collectionType,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<BTResponse<BangumiUserSubjectCollection>> getCollectionSubject(
    String username,
    int subjectId,
  ) async {
    return await _remoteDataSource.getCollectionSubject(username, subjectId);
  }

  @override
  Future<BTResponse<void>> addCollectionSubject(int subjectId) async {
    return await _remoteDataSource.addCollectionSubject(subjectId);
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
    return await _remoteDataSource.updateCollectionSubject(
      subjectId,
      type: type,
      rate: rate,
      ep: ep,
      vol: vol,
      comment: comment,
      private: private,
      tags: tags,
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
    return await _remoteDataSource.getCollectionEpisodes(
      subjectId,
      offset: offset,
      limit: limit,
      type: type,
    );
  }

  @override
  Future<BTResponse<BangumiUserEpisodeCollection>> getCollectionEpisode(
    int episodeId,
  ) async {
    return await _remoteDataSource.getCollectionEpisode(episodeId);
  }

  @override
  Future<BTResponse<void>> updateCollectionEpisode({
    required BangumiEpisodeCollectionType type,
    required int episode,
  }) async {
    return await _remoteDataSource.updateCollectionEpisode(
      type: type,
      episode: episode,
    );
  }
}
