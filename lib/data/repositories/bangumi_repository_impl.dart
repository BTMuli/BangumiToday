// Project imports:
import '../../domain/repositories/bangumi_repository.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_subject.dart';
import '../../tools/log_tool.dart';
import '../datasources/bangumi_local_data_source.dart';
import '../datasources/bangumi_remote_data_source.dart';

typedef _EpisodePageKey = ({
  int subject,
  BangumiLegacyEpisodeType? type,
  int? limit,
  int? offset,
});

class _EpisodePageEntry {
  late final Future<BTResponse<BangumiPageT<BangumiEpisode>>> result;
  DateTime? completedAt;
}

class BTBangumiRepositoryImpl implements BTBangumiRepository {
  final BTBangumiRemoteDataSource _remoteDataSource;
  final BTBangumiLocalDataSource _localDataSource;

  // 首屏预取、剧集展示和本地文件匹配共用短期分页，避免先后重复请求。
  // 仅缓存公开章节，不缓存用户观看状态；显式刷新会清除整个条目的分页。
  final _episodePages = <_EpisodePageKey, _EpisodePageEntry>{};
  static const _episodePageMaxAge = Duration(minutes: 1);
  static const _maxEpisodePages = 128;

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
    var remote = await _remoteDataSource.getSubjectDetail(id);
    var subject = remote.data;
    if (remote.code != 0 || subject == null || subject.nameCn.isNotEmpty) {
      return remote;
    }
    // Bangumi 没有译名时沿用首页的 bangumi-data，保留接口原始缓存。
    try {
      var nameCn = await _localDataSource.getSubjectNameCn(subject.id);
      if (nameCn != null && nameCn.isNotEmpty) {
        return BTResponse(
          code: remote.code,
          message: remote.message,
          data: BangumiSubject.fromJson(subject.toJson()..['name_cn'] = nameCn),
        );
      }
    } catch (error) {
      BTLogTool.warn('读取条目 ${subject.id} 的本地中文标题失败：$error');
    }
    return remote;
  }

  @override
  Future<BTResponse<List<BangumiSubjectRelation>>> getSubjectRelations(
    int id,
  ) async {
    return await _remoteDataSource.getSubjectRelations(id);
  }

  @override
  Future<BTResponse<List<BangumiRelatedCharacter>>> getSubjectCharacters(
    int id,
  ) => _remoteDataSource.getSubjectCharacters(id);

  @override
  Future<BTResponse<List<BangumiRelatedPerson>>> getSubjectPersons(int id) =>
      _remoteDataSource.getSubjectPersons(id);

  @override
  Future<BTResponse<BangumiPageT<BangumiSubjectComment>>> getSubjectComments(
    int id, {
    BangumiCollectionType? type,
    int offset = 0,
    int limit = 20,
  }) => _remoteDataSource.getSubjectComments(
    id,
    type: type,
    offset: offset,
    limit: limit,
  );

  @override
  Future<BTResponse<BangumiPageT<BangumiEpisode>>> getEpisodeList(
    int id, {
    BangumiLegacyEpisodeType? type,
    int? limit,
    int? offset,
  }) {
    var now = DateTime.now();
    _episodePages.removeWhere((_, entry) {
      var completed = entry.completedAt;
      return completed != null &&
          now.difference(completed) >= _episodePageMaxAge;
    });
    var key = (subject: id, type: type, limit: limit, offset: offset);
    var cached = _episodePages[key];
    if (cached != null) return cached.result;
    while (_episodePages.length >= _maxEpisodePages) {
      _episodePages.remove(_episodePages.keys.first);
    }
    var entry = _EpisodePageEntry();
    _episodePages[key] = entry;
    return entry.result = _loadEpisodePage(key, entry);
  }

  Future<BTResponse<BangumiPageT<BangumiEpisode>>> _loadEpisodePage(
    _EpisodePageKey key,
    _EpisodePageEntry entry,
  ) async {
    try {
      var response = await _remoteDataSource.getEpisodeList(
        key.subject,
        type: key.type,
        limit: key.limit,
        offset: key.offset,
      );
      if (response.code == 0 && response.data != null) {
        entry.completedAt = DateTime.now();
      } else if (identical(_episodePages[key], entry)) {
        _episodePages.remove(key);
      }
      return response;
    } catch (_) {
      if (identical(_episodePages[key], entry)) _episodePages.remove(key);
      rethrow;
    }
  }

  @override
  void invalidateEpisodeList(int subject) {
    _episodePages.removeWhere((key, _) => key.subject == subject);
  }

  @override
  Future<BTResponse<BangumiEpisodeDetail>> getEpisodeDetail(int episodeId) =>
      _remoteDataSource.getEpisodeDetail(episodeId);

  @override
  Future<BTResponse<List<BangumiEpisodeComment>>> getEpisodeComments(
    int episodeId,
  ) => _remoteDataSource.getEpisodeComments(episodeId);

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
    }
    // 远程失败时不能回退成本地缓存的“成功”响应：刷新流程只判断 code，
    // 回退会让 5xx（如 502）被当成“收藏写入完成”。本地缓存由
    // getLocalCollections 直接提供给展示层，这里的失败照常上抛。
    return remote;
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
    bool Function()? authScope,
  }) async {
    return await _remoteDataSource.updateCollectionEpisode(
      type: type,
      episode: episode,
      authScope: authScope,
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

  @override
  Future<BangumiUserSubjectCollection?> getLocalCollection(int subjectId) {
    return _localDataSource.getCollection(subjectId);
  }
}
