// Project imports:
import '../../domain/repositories/bangumi_repository.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_subject.dart';
import '../datasources/bangumi_local_data_source.dart';
import '../datasources/bangumi_remote_data_source.dart';

class BTBangumiRepositoryImpl implements BTBangumiRepository {
  final BTBangumiRemoteDataSource _remoteDataSource;
  final BTBangumiLocalDataSource _localDataSource;

  BTBangumiRepositoryImpl({
    required BTBangumiRemoteDataSource remoteDataSource,
    required BTBangumiLocalDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

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
    var remote = await _remoteDataSource.getCollectionSubjects(
      username: username,
      subjectType: subjectType,
      collectionType: collectionType,
      limit: limit,
      offset: offset,
    );
    if (remote.code == 0 && remote.data != null) {
      await _localDataSource.writeList(remote.data!.data);
      return remote;
    }
    var local = collectionType == null
        ? await _localDataSource.getCollections()
        : await _localDataSource.getByType(collectionType);
    if (local.isEmpty) return remote;
    return BTResponse.success(
      data: BangumiPageT(
        total: local.length,
        limit: local.length,
        offset: 0,
        data: local,
      ),
    );
  }

  @override
  Future<BTResponse<BangumiUserSubjectCollection>> getCollectionSubject(
    String username,
    int subjectId,
  ) async {
    var remote = await _remoteDataSource.getCollectionSubject(
      username,
      subjectId,
    );
    if (remote.code == 0 && remote.data != null) {
      await _localDataSource.insertCollection(remote.data!);
      return remote;
    }
    if (remote.code == 404) {
      await _localDataSource.deleteCollection(subjectId);
      return remote;
    }
    var cached = await _localDataSource.getCollection(subjectId);
    if (cached != null) {
      return BTResponse.success(data: cached);
    }
    return remote;
  }

  @override
  Future<BTResponse<void>> addCollectionSubject(int subjectId) async {
    var remote = await _remoteDataSource.addCollectionSubject(subjectId);
    if (remote.code != 0) return remote;
    await _patchLocalCollection(subjectId);
    return remote;
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
    var remote = await _remoteDataSource.updateCollectionSubject(
      subjectId,
      type: type,
      rate: rate,
      ep: ep,
      vol: vol,
      comment: comment,
      private: private,
      tags: tags,
    );
    if (remote.code != 0) return remote;
    await _patchLocalCollection(
      subjectId,
      type: type,
      rate: rate,
      ep: ep,
      vol: vol,
      comment: comment,
      private: private,
      tags: tags,
    );
    return remote;
  }

  Future<void> _patchLocalCollection(
    int subjectId, {
    BangumiCollectionType? type,
    int? rate,
    int? ep,
    int? vol,
    String? comment,
    bool? private,
    List<String>? tags,
  }) async {
    var existing = await _localDataSource.getCollection(subjectId);
    if (existing == null) return;
    if (type != null) existing.type = type;
    if (rate != null) existing.rate = rate;
    if (ep != null) existing.epStatus = ep;
    if (vol != null) existing.volStatus = vol;
    if (comment != null) existing.comment = comment;
    if (private != null) existing.private = private;
    if (tags != null) existing.tags = tags;
    await _localDataSource.updateCollection(existing);
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

  @override
  Future<Set<int>> getCollectedSubjectIds() {
    return _localDataSource.getAllSubjectIds();
  }

  @override
  Future<List<BangumiUserSubjectCollection>> getLocalCollections({
    BangumiCollectionType? type,
  }) async {
    if (type == null) return _localDataSource.getCollections();
    return _localDataSource.getByType(type);
  }
}
