// Dart imports:
import 'dart:async';

// Project imports:
import '../../domain/repositories/bangumi_repository.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/bangumi_subject_browse.dart';
import '../../models/bangumi/request_subject.dart';
import '../../tools/log_tool.dart';
import '../datasources/bangumi_local_data_source.dart';
import '../datasources/bangumi_remote_data_source.dart';

typedef _EpisodePageKey = ({
  int source,
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
  final BangumiAccountSession Function() _accountSession;
  final int Function() _requestSource;
  final _subjectRevisions = <int, int>{};
  final _pendingWrites = <(BangumiAccountSession, int)>{};
  final _collectionReads =
      <
        (BangumiAccountSession, int),
        Future<BTResponse<BangumiUserSubjectCollection>>
      >{};
  int _snapshotRevision = 0;
  int _collectionRevision = 0;

  // 首屏预取、剧集展示和本地文件匹配共用短期分页，避免先后重复请求。
  // 仅缓存公开章节，不缓存用户观看状态；显式刷新会清除整个条目的分页。
  final _episodePages = <_EpisodePageKey, _EpisodePageEntry>{};
  static const _episodePageMaxAge = Duration(minutes: 1);
  static const _maxEpisodePages = 128;

  BTBangumiRepositoryImpl({
    required BTBangumiRemoteDataSource remoteDataSource,
    required BTBangumiLocalDataSource localDataSource,
    required BangumiAccountSession Function() accountSession,
    int Function()? requestSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource,
       _accountSession = accountSession,
       _requestSource = requestSource ?? _defaultRequestSource;

  static int _defaultRequestSource() => 0;

  bool _current(BangumiAccountSession session) =>
      session.username != null && session == _accountSession();

  (int, int) _version(int subject) =>
      (_snapshotRevision, _subjectRevisions[subject] ?? 0);

  void _touch(int subject) {
    _subjectRevisions.update(subject, (value) => value + 1, ifAbsent: () => 1);
    _collectionRevision++;
  }

  BTResponse<T> _changed<T>() =>
      BTResponse(code: 409, message: '账号或收藏状态已变化，请重新刷新', data: null);

  @override
  Future<BTResponse<List<BangumiCalendarRespData>>> getToday() async {
    return await _remoteDataSource.getToday();
  }

  @override
  Future<BTResponse<BangumiSubjectBrowsePage>> getSubjectBrowse({
    BangumiSubjectBrowseSort sort = BangumiSubjectBrowseSort.trends,
    int page = 1,
    int? year,
    int? month,
  }) => _remoteDataSource.getSubjectBrowse(
    sort: sort,
    page: page,
    year: year,
    month: month,
  );

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
  Future<BTResponse<BangumiPageT<BangumiSubjectReview>>> getSubjectReviews(
    int id, {
    int offset = 0,
    int limit = 20,
  }) => _remoteDataSource.getSubjectReviews(id, offset: offset, limit: limit);

  @override
  Future<BTResponse<BangumiReviewDetail>> getReviewDetail(int entryId) =>
      _remoteDataSource.getReviewDetail(entryId);

  @override
  Future<BTResponse<List<BangumiEpisodeComment>>> getReviewComments(
    int entryId,
  ) => _remoteDataSource.getReviewComments(entryId);

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
    var key = (
      source: _requestSource(),
      subject: id,
      type: type,
      limit: limit,
      offset: offset,
    );
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
      if (key.source != _requestSource()) {
        return BTResponse.error(
          code: 499,
          message: '接口设置已变化，请重新读取章节',
          data: null,
        );
      }
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
    var session = _accountSession();
    var result = await _remoteDataSource.getUserInfo();
    return session == _accountSession() ? result : _changed();
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
    var session = _accountSession();
    if (!_current(session) ||
        (username != null && username != '-' && username != session.username)) {
      return _changed();
    }
    var remote = await _remoteDataSource.getCollectionSubjects(
      username: session.username,
      subjectType: subjectType,
      collectionType: collectionType,
      limit: limit,
      offset: offset,
      authScope: () => _current(session),
    );
    if (!_current(session)) return _changed();
    // A page is not a complete snapshot. syncCollections owns persistence;
    // failures also stay failures instead of falling back to a cached success.
    return remote;
  }

  @override
  Future<BTResponse<void>> syncCollections({
    BangumiCollectionType? type,
    void Function(int completed, int total)? onProgress,
  }) async {
    var session = _accountSession();
    var revision = _collectionRevision;
    bool current() =>
        _current(session) &&
        revision == _collectionRevision &&
        !_pendingWrites.any((key) => key.$1 == session);
    if (!current()) return _changed();
    var items = <BangumiUserSubjectCollection>[];
    var ids = <int>{};
    int? total;
    var offset = 0;
    const limit = 50;
    try {
      while (true) {
        var response = await _remoteDataSource.getCollectionSubjects(
          username: session.username,
          collectionType: type,
          limit: limit,
          offset: offset,
          authScope: current,
        );
        if (!current()) return _changed();
        var page = response.data;
        if (response.code != 0 || page == null) {
          return BTResponse(
            code: response.code == 0 ? 666 : response.code,
            message: response.message,
            data: null,
          );
        }
        total ??= page.total;
        if (page.offset != offset ||
            page.total != total ||
            total < 0 ||
            page.data.length > limit ||
            offset + page.data.length > total ||
            (page.data.isEmpty && offset < total) ||
            page.data.any(
              (item) =>
                  item.subjectId != item.subject.id ||
                  (type != null && item.type != type) ||
                  !ids.add(item.subjectId),
            )) {
          return BTResponse(code: 409, message: '收藏分页不完整或已变化，请重试', data: null);
        }
        items.addAll(page.data);
        offset += page.data.length;
        onProgress?.call(offset, total);
        if (offset >= total) break;
      }
      if (type != null) {
        // Absence from a category can mean a move to another category. Resolve
        // those rows before applying deletions, keeping all writes atomic.
        var previous = await _localDataSource.getByType(type);
        if (!current()) return _changed();
        for (var old in previous.where(
          (item) => !ids.contains(item.subjectId),
        )) {
          var response = await _remoteDataSource.getCollectionSubject(
            session.username!,
            old.subjectId,
            fresh: true,
            authScope: current,
          );
          if (!current()) return _changed();
          if (response.code == 404) continue;
          var item = response.data;
          if (response.code != 0 ||
              item == null ||
              item.subjectId != old.subjectId ||
              item.subject.id != old.subjectId) {
            return BTResponse(
              code: response.code == 0 ? 666 : response.code,
              message: '核对收藏状态失败，请重试：${response.message}',
              data: null,
            );
          }
          items.add(item);
        }
      }
      var saved = await _localDataSource.writeScoped(
        () => _localDataSource.replaceCollections(items, type: type),
        isCurrent: current,
      );
      if (!saved) return _changed();
      _snapshotRevision++;
      _collectionRevision++;
      return BTResponse(code: 0, message: '收藏同步完成', data: null);
    } catch (error) {
      return BTResponse(code: 666, message: '同步收藏失败：$error', data: null);
    }
  }

  @override
  Future<BTResponse<BangumiUserSubjectCollection>> getCollectionSubject(
    String username,
    int subjectId,
  ) async {
    var session = _accountSession();
    if (username != '-' && username != session.username) return _changed();
    return _queueCollectionSubjectRead(session, subjectId, removeMissing: true);
  }

  @override
  Future<BTResponse<BangumiUserSubjectCollection>> refreshCollectionSubject(
    int subjectId, {
    bool Function()? authScope,
  }) => _queueCollectionSubjectRead(
    _accountSession(),
    subjectId,
    fresh: true,
    authScope: authScope,
  );

  Future<BTResponse<BangumiUserSubjectCollection>> _queueCollectionSubjectRead(
    BangumiAccountSession session,
    int subjectId, {
    bool removeMissing = false,
    bool fresh = false,
    bool Function()? authScope,
  }) => _queueCollectionSubjectOperation(
    session,
    subjectId,
    () => _readCollectionSubject(
      session,
      subjectId,
      removeMissing: removeMissing,
      fresh: fresh,
      authScope: authScope,
    ),
  );

  Future<BTResponse<BangumiUserSubjectCollection>>
  _queueCollectionSubjectOperation(
    BangumiAccountSession session,
    int subjectId,
    Future<BTResponse<BangumiUserSubjectCollection>> Function() operation,
  ) {
    var key = (session, subjectId);
    var previous = _collectionReads[key];
    late Future<BTResponse<BangumiUserSubjectCollection>> future;
    future =
        () async {
          if (previous != null) {
            try {
              await previous;
            } catch (_) {
              // A failed refresh must not prevent later chapter edits syncing.
            }
          }
          // Reads and local chapter updates share a revision and must commit
          // in order without invalidating one another.
          return operation();
        }().whenComplete(() {
          if (identical(_collectionReads[key], future)) {
            unawaited(_collectionReads.remove(key));
          }
        });
    _collectionReads[key] = future;
    return future;
  }

  @override
  Future<BTResponse<void>> saveLocalCollectionProgress(
    int subjectId,
    int collectedEpisodes, {
    required bool Function() authScope,
  }) async {
    var session = _accountSession();
    var response = await _queueCollectionSubjectOperation(
      session,
      subjectId,
      () async {
        var version = _version(subjectId);
        bool current() =>
            _current(session) &&
            version == _version(subjectId) &&
            !_pendingWrites.contains((session, subjectId)) &&
            authScope();
        if (!current()) return _changed();
        var saved = await _localDataSource.writeScoped(() async {
          var collection = await _localDataSource.getCollection(subjectId);
          if (collection == null || collection.epStatus == collectedEpisodes) {
            return;
          }
          collection.epStatus = collectedEpisodes;
          await _localDataSource.updateCollection(collection);
        }, isCurrent: current);
        if (!saved) return _changed();
        _touch(subjectId);
        return BTResponse<BangumiUserSubjectCollection>(
          code: 0,
          message: '本地收藏进度已保存',
          data: null,
        );
      },
    );
    return BTResponse(
      code: response.code,
      message: response.message,
      data: null,
    );
  }

  Future<BTResponse<BangumiUserSubjectCollection>> _readCollectionSubject(
    BangumiAccountSession session,
    int subjectId, {
    bool removeMissing = false,
    bool fresh = false,
    bool Function()? authScope,
    bool afterWrite = false,
  }) async {
    var version = _version(subjectId);
    bool current() =>
        _current(session) &&
        version == _version(subjectId) &&
        (afterWrite || !_pendingWrites.contains((session, subjectId))) &&
        (authScope?.call() ?? true);
    if (!current()) return _changed();
    var remote = await _remoteDataSource.getCollectionSubject(
      session.username!,
      subjectId,
      fresh: fresh,
      authScope: current,
    );
    if (!current()) return _changed();
    if (remote.code == 0 && remote.data != null) {
      if (remote.data!.subjectId != subjectId ||
          remote.data!.subject.id != subjectId) {
        return BTResponse(code: 666, message: '收藏条目身份不匹配', data: null);
      }
      var saved = await _localDataSource.writeScoped(
        () => _localDataSource.insertCollection(remote.data!),
        isCurrent: current,
      );
      if (!saved) return _changed();
      _touch(subjectId);
      return remote;
    }
    if (remote.code == 404 && removeMissing) {
      var saved = await _localDataSource.writeScoped(
        () => _localDataSource.deleteCollection(subjectId),
        isCurrent: current,
      );
      if (!saved) return _changed();
      _touch(subjectId);
      return remote;
    }
    if (!removeMissing) return remote;
    var cached = await _localDataSource.getCollection(subjectId);
    if (!current()) return _changed();
    if (cached != null) {
      return BTResponse.success(data: cached);
    }
    return remote;
  }

  @override
  Future<BTResponse<void>> addCollectionSubject(int subjectId) =>
      _writeCollection(subjectId, add: true, type: BangumiCollectionType.wish);

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
  }) => _writeCollection(
    subjectId,
    type: type,
    rate: rate,
    ep: ep,
    vol: vol,
    comment: comment,
    private: private,
    tags: tags,
  );

  Future<BTResponse<void>> _writeCollection(
    int subjectId, {
    bool add = false,
    BangumiCollectionType? type,
    int? rate,
    int? ep,
    int? vol,
    String? comment,
    bool? private,
    List<String>? tags,
  }) async {
    var session = _accountSession();
    var key = (session, subjectId);
    if (!_current(session) || !_pendingWrites.add(key)) return _changed();
    _touch(subjectId);
    var version = _version(subjectId);
    bool current() => _current(session) && version == _version(subjectId);
    try {
      var remote = add
          ? await _remoteDataSource.addCollectionSubject(
              subjectId,
              authScope: current,
            )
          : await _remoteDataSource.updateCollectionSubject(
              subjectId,
              type: type,
              rate: rate,
              ep: ep,
              vol: vol,
              comment: comment,
              private: private,
              tags: tags,
              authScope: current,
            );
      if (!current()) return _changed();
      if (remote.code != 0) return remote;
      return await _patchLocalCollection(
        session,
        subjectId,
        version,
        type: type,
        rate: rate,
        ep: ep,
        vol: vol,
        comment: comment,
        private: private,
        tags: tags,
      );
    } finally {
      _pendingWrites.remove(key);
    }
  }

  Future<BTResponse<void>> _patchLocalCollection(
    BangumiAccountSession session,
    int subjectId,
    (int, int) version, {
    BangumiCollectionType? type,
    int? rate,
    int? ep,
    int? vol,
    String? comment,
    bool? private,
    List<String>? tags,
  }) async {
    bool current() => _current(session) && version == _version(subjectId);
    var existing = await _localDataSource.getCollection(subjectId);
    if (!current()) return _changed();
    if (existing == null) {
      var fresh = await _readCollectionSubject(
        session,
        subjectId,
        fresh: true,
        authScope: current,
        afterWrite: true,
      );
      return BTResponse(
        code: fresh.code == 0 && fresh.data != null
            ? 0
            : fresh.code == 0
            ? 666
            : fresh.code,
        message: fresh.code == 0 && fresh.data != null
            ? '收藏同步完成'
            : '收藏已保存，本地同步失败，请刷新收藏：${fresh.message}',
        data: null,
      );
    }
    if (type != null) existing.type = type;
    if (rate != null) existing.rate = rate;
    if (ep != null) existing.epStatus = ep;
    if (vol != null) existing.volStatus = vol;
    if (comment != null) existing.comment = comment;
    if (private != null) existing.private = private;
    if (tags != null) existing.tags = tags;
    existing.updatedAt = DateTime.now().toUtc().toIso8601String();
    var saved = await _localDataSource.writeScoped(
      () => _localDataSource.updateCollection(existing),
      isCurrent: current,
    );
    if (!saved) return _changed();
    _touch(subjectId);
    return BTResponse(code: 0, message: '收藏同步完成', data: null);
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
  Future<Set<int>> getCollectedSubjectIds() async {
    var session = _accountSession();
    if (!_current(session)) return {};
    var ids = await _localDataSource.getAllSubjectIds();
    return _current(session) ? ids : {};
  }

  @override
  Stream<Map<int, BangumiCollectionType>> watchLocalCollectionTypes() {
    var session = _accountSession();
    if (!_current(session)) return Stream.value(const {});
    return _localDataSource.watchCollectionTypes().map(
      (types) => _current(session) ? types : const {},
    );
  }

  @override
  Stream<List<BangumiUserSubjectCollection>> watchLocalCollections({
    BangumiCollectionType? type,
  }) {
    var session = _accountSession();
    if (!_current(session)) return Stream.value(const []);
    return _localDataSource
        .watchCollections(type: type)
        .map((items) => _current(session) ? items : const []);
  }

  @override
  Stream<BangumiUserSubjectCollection?> watchLocalCollection(int subjectId) {
    var session = _accountSession();
    if (!_current(session)) return Stream.value(null);
    return _localDataSource
        .watchCollection(subjectId)
        .map((item) => _current(session) ? item : null);
  }

  @override
  Future<List<BangumiUserSubjectCollection>> getLocalCollections({
    BangumiCollectionType? type,
  }) async {
    var session = _accountSession();
    if (!_current(session)) return [];
    var items = type == null
        ? await _localDataSource.getCollections()
        : await _localDataSource.getByType(type);
    return _current(session) ? items : [];
  }

  @override
  Future<BangumiUserSubjectCollection?> getLocalCollection(
    int subjectId,
  ) async {
    var session = _accountSession();
    if (!_current(session)) return null;
    var item = await _localDataSource.getCollection(subjectId);
    return _current(session) ? item : null;
  }
}
