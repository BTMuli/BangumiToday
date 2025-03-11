// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_collection.dart';
import '../../models/bangumi/request_episode.dart';
import '../../models/bangumi/request_search.dart';
import '../../models/bangumi/request_subject.dart';
import '../../models/bangumi/request_user.dart';
import '../../store/bgm_user_hive.dart';
import '../../tools/log_tool.dart';
import '../core/client.dart';

/// bangumi.tv 的 API
/// 详细文档请参考 https://bangumi.github.io/api/
class BtrBangumiApi {
  /// 请求客户端
  late final BtrClient client;

  /// 基础 URL
  final String baseUrl = 'https://api.bgm.tv';

  /// 用户Hive
  final BgmUserHive hive = BgmUserHive();

  /// 构造函数
  BtrBangumiApi() {
    client = BtrClient.withHeader();
    client.dio.options.baseUrl = baseUrl;
  }

  /// 获取需要访问令牌的 header 项
  Map<String, dynamic> getAuthHeader() {
    if (hive.tokenAC == null || hive.tokenAC!.isEmpty) {
      return client.dio.options.headers;
    }
    return {
      ...client.dio.options.headers,
      'Authorization': 'Bearer ${hive.tokenAC}',
    };
  }

  /// 条目模块

  /// 每日放送
  Future<BTResponse> getToday() async {
    try {
      var response = await client.dio.get('/calendar');
      var data = response.data as List;
      var list = data
          .map(
            (e) => BangumiCalendarRespData.fromJson(e as Map<String, dynamic>),
          )
          .toList();
      return BangumiCalendarResp.success(data: list);
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error('Failed to load today: ${jsonEncode(errResp)}');
      return BTResponse<BangumiErrorDetail>(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load today',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to load today: $e');
      return BTResponse.error(
        code: 666,
        message: 'Failed to load today',
        data: null,
      );
    }
  }

  /// 条目搜索
  /// [sort] 为排序规则，有 match(默认)-匹配度, heat-收藏人数，rank-排名，score-评分
  /// 其余属性都是 filter
  /// [type] 为条目类型，或关系
  /// [tag] 为标签，且关系
  /// [airdate] 为放送日期，且关系，例：[">=2020-07-01", "<2020-10-01"]
  /// [rating] 为评分，且关系，例：[">=6", "<8"]
  /// [rank] 为排名，且关系，例：[">=100", "<=200"]
  /// [nsfw] 为是否显示 nsfw 内容，无权限与 nsfw 为 false 时无法获取 nsfw 内容
  /// 默认或者 null 会包括所有类型，true 为只返回 nsfw 内容
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
    bool? nsfw = false,
  }) async {
    var data = <String, dynamic>{'keyword': keyword, 'sort': sort};
    var filter = <String, dynamic>{};
    if (type.isNotEmpty) filter['type'] = type.map((e) => e.value).toList();
    if (tag != null) filter['tag'] = tag;
    if (airdate != null) filter['airdate'] = airdate;
    if (rating != null) filter['rating'] = rating;
    if (rank != null) filter['rank'] = rank;
    filter['nsfw'] = nsfw;
    data['filter'] = filter;
    var params = <String, dynamic>{'limit': limit, 'offset': offset};
    BTLogTool.info('searchSubjectsData: ${jsonEncode(data)}');
    BTLogTool.info('searchSubjectsParams: ${jsonEncode(params)}');
    try {
      var authHeader = getAuthHeader();
      var resp = await client.dio.post(
        '/v0/search/subjects',
        queryParameters: params,
        data: data,
        options: Options(contentType: 'application/json', headers: authHeader),
      );
      var list = BangumiPageT<BangumiSubjectSearchData>.fromJson(
        resp.data as Map<String, dynamic>,
        (e) => BangumiSubjectSearchData.fromJson(e as Map<String, dynamic>),
      );
      return BangumiSubjectSearchResp.success(data: list);
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error('Failed to search subjects: ${jsonEncode(errResp)}');
      return BTResponse<BangumiErrorDetail>(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to search subjects',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to search subjects: $e');
      return BTResponse.error(
        code: 666,
        message: 'Failed to search subjects',
        data: null,
      );
    }
  }

  /// 获取番剧详情
  Future<BTResponse> getSubjectDetail(String id) async {
    try {
      var authHeader = getAuthHeader();
      var resp = await client.dio.get(
        '/v0/subjects/$id',
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      assert(resp.data is Map<String, dynamic>);
      return BangumiSubjectResp.success(
        data: BangumiSubject.fromJson(resp.data),
      );
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error('Failed to load subject detail: ${jsonEncode(errResp)}');
      return BTResponse<BangumiErrorDetail>(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load subject detail',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to load subject detail: $e');
      return BTResponse.error(
        code: 666,
        message: 'Failed to load subject detail',
        data: null,
      );
    }
  }

  /// 获取条目关联条目
  Future<BTResponse> getSubjectRelations(int id) async {
    try {
      var authHeader = getAuthHeader();
      var resp = await client.dio.get(
        '/v0/subjects/$id/subjects',
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      var list = resp.data as List;
      var data = list
          .map(
            (e) => BangumiSubjectRelation.fromJson(e as Map<String, dynamic>),
          )
          .toList();
      return BangumiSubjectRelationsResp.success(data: data);
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error(
        'Failed to load subject relations: ${jsonEncode(errResp)}',
      );
      return BTResponse<BangumiErrorDetail>(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load subject relations',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to load subject relations: $e');
      return BTResponse.error(
        code: 666,
        message: 'Failed to load subject relations',
        data: null,
      );
    }
  }

  /// 章节模块

  /// 获取某条目的章节信息
  Future<BTResponse> getEpisodeList(
    int id, {
    BangumiLegacyEpisodeType? type,
    int? limit,
    int? offset,
  }) async {
    var params = <String, dynamic>{'subject_id': id};
    if (type != null) params['type'] = type.value;
    if (limit != null) params['limit'] = limit;
    if (offset != null) params['offset'] = offset;
    try {
      var authHeader = getAuthHeader();
      var resp = await client.dio.get(
        '/v0/episodes',
        queryParameters: params,
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      var dataList = BangumiPageT<BangumiEpisode>.fromJson(
        resp.data as Map<String, dynamic>,
        (e) => BangumiEpisode.fromJson(
          e as Map<String, dynamic>,
        ),
      );
      return BangumiEpisodeListResp.success(data: dataList);
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error('Failed to load episode list: ${jsonEncode(errResp)}');
      return BTResponse<BangumiErrorDetail>(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load episode list',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to load episode list: $e');
      return BTResponse.error(
        code: 666,
        message: 'Failed to load episode list',
        data: null,
      );
    }
  }

  /// 用户模块

  /// 获取用户信息
  Future<BTResponse> getUserInfo() async {
    try {
      var authHeader = getAuthHeader();
      var resp = await client.dio.get(
        '/v0/me',
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      return BangumiUserInfoResp.success(
        data: BangumiUser.fromJson(resp.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error('Failed to load user info: ${jsonEncode(errResp)}');
      return BTResponse<BangumiErrorDetail>(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load user info',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to load user info: $e');
      return BTResponse.error(
        code: 666,
        message: 'Failed to load user info',
        data: null,
      );
    }
  }

  /// 收藏模块

  /// 获取用户收藏
  Future<BTResponse> getCollectionSubjects({
    required String username,
    BangumiSubjectType? subjectType,
    BangumiCollectionType? collectionType,
    int? limit,
    int? offset,
  }) async {
    var params = <String, dynamic>{};
    if (subjectType != null) params['subject_type'] = subjectType.value;
    if (collectionType != null) params['type'] = collectionType.value;
    if (limit != null) params['limit'] = limit;
    if (offset != null) params['offset'] = offset;
    try {
      var authHeader = getAuthHeader();
      var resp = await client.dio.get(
        '/v0/users/$username/collections',
        queryParameters: params,
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      var dataList = BangumiPageT<BangumiUserSubjectCollection>.fromJson(
        resp.data as Map<String, dynamic>,
        (e) => BangumiUserSubjectCollection.fromJson(
          e as Map<String, dynamic>,
        ),
      );
      return BangumiCollectionSubjectListResp.success(data: dataList);
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error(
          'Failed to load user collections: ${jsonEncode(errResp)}');
      return BTResponse<BangumiErrorDetail>(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load user collections',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to load user collections: $e');
      return BTResponse.error(
        code: 666,
        message: 'Failed to load user collections',
        data: null,
      );
    }
  }

  /// 获取用户单个收藏
  Future<BTResponse> getCollectionSubject(
    String username,
    int subjectId,
  ) async {
    try {
      var authHeader = getAuthHeader();
      var resp = await client.dio.get(
        '/v0/users/$username/collections/$subjectId',
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      assert(resp.data is Map<String, dynamic>);
      if (resp.data.containsKey('request_id')) {
        var failResp = BangumiErrorDetail.fromJson(resp.data);
        return BTResponse<BangumiErrorDetail>(
          code: 404,
          message: 'User collection item not found',
          data: failResp,
        );
      }
      return BangumiCollectionSubjectItemResp.success(
        data: BangumiUserSubjectCollection.fromJson(resp.data),
      );
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      var code = e.response?.statusCode ?? 666;
      if (code == 404) {
        return BTResponse.error(
          code: code,
          message: 'User collection item not found',
          data: errResp,
        );
      }
      BTLogTool.error(
        'Failed to load user collection item: ${jsonEncode(errResp)}',
      );
      return BTResponse<BangumiErrorDetail>(
        code: code,
        message: 'Failed to load user collection item',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to load user collection item: $e');
      return BTResponse.error(
        code: 666,
        message: 'Failed to load user collection item',
        data: null,
      );
    }
  }

  /// 新增用户单个条目的收藏
  Future<BTResponse> addCollectionSubject(int subjectId) async {
    try {
      var authHeader = getAuthHeader();
      await client.dio.post(
        '/v0/users/-/collections/$subjectId',
        data: {'type': BangumiCollectionType.wish.value},
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      return BTResponse.success(data: null);
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error(
          'Failed to add user collection item: ${jsonEncode(errResp)}');
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to add user collection item',
        data: errResp,
      );
    } on Exception catch (e) {
      return BTResponse.error(
        code: 666,
        message: 'Failed to add user collection item',
        data: e.toString(),
      );
    }
  }

  /// 更新用户单个条目收藏信息
  /// 直接修改完成度可能会造成预期外的错误，这边建议只修改状态\评分等信息
  /// bug: 无法修改评分，见 https://github.com/bangumi/server/issues/530
  Future<BTResponse> updateCollectionSubject(
    int subjectId, {
    BangumiCollectionType? type,
    int? rate,
    int? ep,
    int? vol,
    String? comment,
    bool? private,
    List<String>? tags,
  }) async {
    var data = <String, dynamic>{};
    if (type != null) data['type'] = type.value;
    if (rate != null) data['rate'] = rate;
    if (ep != null) data['ep_status'] = ep;
    if (vol != null) data['vol_status'] = vol;
    if (comment != null) data['comment'] = comment;
    if (private != null) data['private'] = private;
    if (tags != null) data['tags'] = tags;
    try {
      var authHeader = getAuthHeader();
      var resp = await client.dio.patch(
        '/v0/users/-/collections/$subjectId',
        data: data,
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      return BTResponse.success(data: resp.data);
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error(
          'Failed to update user collection item: ${jsonEncode(errResp)}');
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to update user collection item',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to update user collection item: $e');
      return BTResponse.error(
        code: 666,
        message: 'Failed to update user collection item',
        data: e.toString(),
      );
    }
  }

  /// 获取用户章节收藏
  Future<BTResponse> getCollectionEpisodes(
    int subjectId, {
    int? offset,
    int? limit,
    BangumiLegacyEpisodeType? type,
  }) async {
    var params = <String, dynamic>{'subject_id': subjectId};
    if (offset != null) params['offset'] = offset;
    if (limit != null) params['limit'] = limit;
    if (type != null) params['type'] = type.value;
    try {
      var authHeader = getAuthHeader();
      var resp = await client.dio.get(
        '/v0/users/-/collections/$subjectId/episodes',
        queryParameters: params,
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      var dataList = BangumiPageT<BangumiUserEpisodeCollection>.fromJson(
        resp.data as Map<String, dynamic>,
        (e) => BangumiUserEpisodeCollection.fromJson(
          e as Map<String, dynamic>,
        ),
      );
      return BangumiCollectionEpisodeListResp.success(data: dataList);
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error(
          'Failed to load user collection episodes: ${jsonEncode(errResp)}');
      return BTResponse<BangumiErrorDetail>(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load user collection episodes',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to load user collection episodes: $e');
      return BTResponse.error(
        code: 666,
        message: 'Failed to load user collection episodes',
        data: null,
      );
    }
  }

  /// 获取用户单个章节收藏
  Future<BTResponse> getCollectionEpisode(int episodeId) async {
    try {
      var authHeader = getAuthHeader();
      var resp = await client.dio.get(
        '/v0/users/-/collections/-/episodes/$episodeId',
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      assert(resp.data is Map<String, dynamic>);
      return BangumiCollectionEpisodeItemResp.success(
        data: BangumiUserEpisodeCollection.fromJson(resp.data),
      );
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error('Failed to load user collection episode item:'
          '${jsonEncode(errResp)}');
      return BTResponse<BangumiErrorDetail>(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load user collection episode item',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to load user collection episode item: $e');
      return BTResponse.error(
        code: 666,
        message: 'Failed to load user collection episode item',
        data: null,
      );
    }
  }

  /// 更新用户单个章节收藏信息
  Future<BTResponse> updateCollectionEpisode({
    required BangumiEpisodeCollectionType type,
    required int episode,
  }) async {
    try {
      var authHeader = getAuthHeader();
      var resp = await client.dio.put(
        '/v0/users/-/collections/-/episodes/$episode',
        queryParameters: {'episode_id': episode},
        data: {'type': type.value},
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      return BTResponse.success(data: resp.data);
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error(
        'Failed to update user collection episode item: ${jsonEncode(errResp)}',
      );
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to update user collection episode item',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to update user collection episode item: $e');
      return BTResponse.error(
        code: 666,
        message: 'Failed to update user collection episode item',
        data: e.toString(),
      );
    }
  }

  /// 搜索模块 ///
  /// 可以指定返回数据大小 [group] 为 small, medium, large
  /// 对应 BangumiLegacySubject(Small|Medium|Large)
  /// 由于返回内容没有 `nsfw` 字段，不支持过滤，故实际采用另一个接口
  /// 该接口测试通过，仍然保留，但是不使用
  Future<BTResponse> searchSubjectsOld(
    String keyword, {
    BangumiSubjectType type = BangumiSubjectType.anime,
    String group = 'small',
    int? start,
    int? maxResults,
  }) async {
    var params = <String, dynamic>{
      'type': type.value,
      'responseGroup': group,
    };
    if (start != null) params['start'] = start;
    if (maxResults != null && maxResults >= 1 && maxResults <= 25) {
      params['max_results'] = maxResults;
    }
    try {
      var resp = await client.dio.get(
        '/search/subject/$keyword',
        queryParameters: params,
        options: Options(contentType: 'application/json'),
      );
      var data = BangumiSearchListData.fromJson(resp.data);
      return BangumiSearchListResp.success(data: data);
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error('Failed to search subjects: ${jsonEncode(errResp)}');
      return BTResponse<BangumiErrorDetail>(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to search subjects',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to search subjects: $e');
      return BTResponse.error(
        code: 666,
        message: 'Failed to search subjects',
        data: null,
      );
    }
  }
}
