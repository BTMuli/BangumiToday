part of 'bangumi_api.dart';

/// One operation captures its account and API selection, including all pages.
class _BangumiPrivateApi {
  _BangumiPrivateApi(this.owner)
    : account = owner._accountSession(),
      generation = BtrBangumiApi._routingGeneration;

  final BtrBangumiApi owner;
  final BangumiRequestAccount account;
  final int generation;

  bool get current =>
      BtrBangumiApi.usePrivateApi &&
      BtrBangumiApi._routingGeneration == generation &&
      owner._accountSession() == account;

  Future<BTResponse<T>> run<T>(
    Future<T> Function() action,
    String message,
  ) async {
    try {
      if (!current) throw const _PrivateApiFailure(499, '账户或接口设置已变化');
      var data = await action();
      if (!current) throw const _PrivateApiFailure(499, '账户或接口设置已变化');
      return BTResponse.success(data: data);
    } on _PrivateApiFailure catch (error) {
      return BTResponse.error(
        code: error.code,
        message: error.message,
        data: null,
      );
    } on DioException catch (error) {
      return handleBangumiDioException(error, fallbackMessage: message);
    } catch (error) {
      BTLogTool.error('$message: $error');
      return BTResponse.error(code: 666, message: message, data: null);
    }
  }

  Future<Response> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
    bool deduplicate = true,
    bool cancelPrevious = false,
    bool Function()? authScope,
  }) async {
    bool scope() => current && (authScope == null || authScope());
    if (!scope()) throw const _PrivateApiFailure(499, '账户或接口设置已变化');
    var url = '${BtrBangumiApi.privateApiBaseUrl}/p1$path';
    var response = await owner._requestManager.request<Response>(
      key: RequestKey.http(
        method,
        url,
        account: account,
        queryParameters: query,
        data: data,
      ),
      deduplicate: deduplicate,
      cancelPrevious: cancelPrevious,
      request: (token) => owner.client.dio.request(
        url,
        queryParameters: query,
        data: data,
        options: Options(
          method: method,
          contentType: Headers.jsonContentType,
          extra: {'authScope': scope},
        ),
        cancelToken: token,
      ),
    );
    if (!scope()) throw const _PrivateApiFailure(499, '账户或接口设置已变化');
    if ((method == 'GET' || path == '/search/subjects') &&
        response.data is! Map &&
        response.data is! List) {
      var failure = handleBangumiUnexpectedResponse(
        response,
        fallbackMessage: '新版 Bangumi 接口返回格式异常',
      );
      throw _PrivateApiFailure(failure.code, failure.message);
    }
    return response;
  }

  Future<List<Map<String, dynamic>>> all(
    String path, {
    int limit = 100,
    bool deduplicate = true,
    bool cancelPrevious = false,
  }) async {
    var items = <Map<String, dynamic>>[];
    int? total;
    while (true) {
      var response = await request(
        path,
        query: {'limit': limit, 'offset': items.length},
        deduplicate: deduplicate,
        cancelPrevious: cancelPrevious,
      );
      var json = BangumiPrivateParser.map(response.data);
      var count = (json['total'] as num).toInt();
      var rows = (json['data'] as List).map(BangumiPrivateParser.map).toList();
      total ??= count;
      if (count < 0 ||
          count != total ||
          rows.length > limit ||
          items.length + rows.length > total ||
          (rows.isEmpty && items.length < total)) {
        throw const _PrivateApiFailure(409, '新版接口分页不完整或已变化，请重试');
      }
      items.addAll(rows);
      if (items.length == total) return items;
    }
  }

  BangumiPageT<T> page<T>(
    dynamic value,
    T Function(dynamic) decode,
    int limit,
    int offset,
  ) {
    var json = BangumiPrivateParser.map(value);
    return BangumiPageT(
      total: (json['total'] as num).toInt(),
      limit: limit,
      offset: offset,
      data: (json['data'] as List).map(decode).toList(),
    );
  }

  Future<BTResponse<List<BangumiCalendarRespData>>> calendar({
    required bool useCache,
    required bool deduplicate,
    required bool cancelPrevious,
    Duration? cacheMaxAge,
  }) => run(() async {
    var key = '${CacheKeys.bangumiCalendar}:p1';
    if (useCache) {
      var cached = await BTCacheManager.instance.get<List<dynamic>>(
        key,
        maxAge: cacheMaxAge ?? CacheDuration.medium,
      );
      if (cached != null) {
        return cached
            .map(
              (e) =>
                  BangumiCalendarRespData.fromJson(BangumiPrivateParser.map(e)),
            )
            .toList();
      }
    }
    var response = await request(
      '/calendar',
      deduplicate: deduplicate,
      cancelPrevious: cancelPrevious,
    );
    var result = BangumiPrivateParser.calendar(response.data);
    for (var day in result) {
      for (var item in day.items) {
        item.url = BtrBangumiApi.rewriteUrl(item.url);
      }
    }
    if (useCache && current) {
      await BTCacheManager.instance.set(
        key,
        result.map((e) => e.toJson()).toList(),
      );
    }
    return result;
  }, '加载新版每日放送失败');

  Future<BTResponse<BangumiSubject>> subject(
    String id, {
    bool deduplicate = true,
    bool cancelPrevious = false,
  }) => run(() async {
    var response = await request(
      '/subjects/$id',
      deduplicate: deduplicate,
      cancelPrevious: cancelPrevious,
    );
    var subject = BangumiPrivateParser.subject(response.data);
    await owner._cacheSubject(subject);
    return subject;
  }, '加载新版条目详情失败');

  Future<BTResponse<BangumiPageT<BangumiSubjectSearchData>>> search(
    Map<String, dynamic> data,
    Map<String, dynamic> query, {
    required bool deduplicate,
    required bool cancelPrevious,
  }) => run(() async {
    var filter = Map<String, dynamic>.from(data['filter'] as Map);
    // /p1's optional Boolean rejects an explicit JSON null.
    if (filter['nsfw'] == null) filter.remove('nsfw');
    if (filter.containsKey('tag')) filter['tags'] = filter.remove('tag');
    if (filter.containsKey('airdate')) {
      filter['date'] = filter.remove('airdate');
    }
    var response = await request(
      '/search/subjects',
      method: 'POST',
      data: {...data, 'filter': filter},
      query: query,
      deduplicate: deduplicate,
      cancelPrevious: cancelPrevious,
    );
    return page(
      response.data,
      BangumiPrivateParser.search,
      query['limit'] as int,
      query['offset'] as int,
    );
  }, '新版条目搜索失败');

  Future<BTResponse<List<T>>> list<T>(
    String path,
    Iterable<T> Function(dynamic) decode,
  ) => run(() async {
    var rows = await all(path);
    return rows.expand(decode).toList();
  }, '加载新版条目资料失败');

  Future<BTResponse<BangumiUser>> user() => run(() async {
    var response = await request('/me');
    return BangumiPrivateParser.user(response.data);
  }, '加载新版用户信息失败');

  Future<BTResponse<BangumiPageT<BangumiUserSubjectCollection>>> collections({
    int? subjectType,
    int? type,
    int limit = 30,
    int offset = 0,
    bool Function()? authScope,
  }) => run(() async {
    var response = await request(
      '/collections/subjects',
      query: {
        'subjectType': ?subjectType,
        'type': ?type,
        'limit': limit,
        'offset': offset,
      },
      authScope: authScope,
    );
    return page(
      response.data,
      BangumiPrivateParser.subjectCollection,
      limit,
      offset,
    );
  }, '加载新版收藏失败');

  Future<BTResponse<BangumiUserSubjectCollection>> collection(
    int subject, {
    required bool deduplicate,
    required bool cancelPrevious,
    bool Function()? authScope,
  }) => run(() async {
    var response = await request(
      '/subjects/$subject',
      deduplicate: deduplicate,
      cancelPrevious: cancelPrevious,
      authScope: authScope,
    );
    var json = BangumiPrivateParser.map(response.data);
    if (json['interest'] == null) {
      throw const _PrivateApiFailure(404, 'User collection item not found');
    }
    return BangumiPrivateParser.subjectCollection(json);
  }, '加载新版单个收藏失败');

  Future<BTResponse<void>> write(
    String path,
    String method,
    Map<String, dynamic> data, {
    bool Function()? authScope,
  }) => run<void>(() async {
    var response = await request(
      path,
      method: method,
      data: data,
      deduplicate: false,
      authScope: authScope,
    );
    var failure = readBangumiWriteFailure(
      response,
      fallbackMessage: '更新新版收藏失败',
    );
    if (failure != null) {
      throw _PrivateApiFailure(failure.code, failure.message);
    }
  }, '更新新版收藏失败');

  Future<List<Map<String, dynamic>>> episodeRows(
    int subject, {
    bool deduplicate = true,
    bool cancelPrevious = false,
  }) async {
    var rows = await all(
      '/subjects/$subject/episodes',
      limit: 1000,
      deduplicate: deduplicate,
      cancelPrevious: cancelPrevious,
    );
    var ids = <int>{};
    for (var row in rows) {
      if (row['subjectID'] != subject || !ids.add(row['id'] as int)) {
        throw const _PrivateApiFailure(409, '新版章节分页重复或条目不匹配，请重试');
      }
    }
    // Match /v0's local numbering: sort - the first normal chapter + 1.
    var first = rows.where((e) => e['type'] == 0).firstOrNull?['sort'] as num?;
    for (var row in rows) {
      row['ep'] = row['type'] == 0 && first != null
          ? (row['sort'] as num) - first + 1
          : 0;
    }
    return rows;
  }

  Future<BTResponse<BangumiPageT<T>>> episodes<T>(
    int subject,
    T Function(dynamic) decode, {
    int? type,
    int limit = 100,
    int offset = 0,
    bool deduplicate = true,
    bool cancelPrevious = false,
  }) => run(() async {
    // Filtering type=0 upstream currently includes specials. Filter the full
    // list before slicing so total, offset and subject-relative ep stay valid.
    var rows = (await episodeRows(
      subject,
      deduplicate: deduplicate,
      cancelPrevious: cancelPrevious,
    )).where((row) => type == null || row['type'] == type).toList();
    return BangumiPageT(
      total: rows.length,
      limit: limit,
      offset: offset,
      data: rows.skip(offset).take(limit).map(decode).toList(),
    );
  }, '加载新版章节失败');

  Future<BTResponse<BangumiUserEpisodeCollection>> episode(int episode) =>
      run(() async {
        var response = await request('/episodes/$episode');
        var json = BangumiPrivateParser.map(response.data);
        var rows = await episodeRows(json['subjectID'] as int);
        var row = rows.where((row) => row['id'] == episode).singleOrNull;
        if (row == null) throw const _PrivateApiFailure(404, '章节不存在');
        return BangumiPrivateParser.episodeCollection(row);
      }, '加载新版章节收藏失败');
}

class _PrivateApiFailure implements Exception {
  const _PrivateApiFailure(this.code, this.message);
  final int code;
  final String message;
}
