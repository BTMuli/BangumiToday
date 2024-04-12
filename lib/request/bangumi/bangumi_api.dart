import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';

import '../../database/bangumi/bangumi_user.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_collection.dart';
import '../../models/bangumi/request_episode.dart';
import '../../models/bangumi/request_subject.dart';
import '../../models/bangumi/request_user.dart';
import '../../tools/log_tool.dart';
import 'bangumi_client.dart';

/// bangumi.tv 的 API
/// 详细文档请参考 https://bangumi.github.io/api/
class BtrBangumiApi {
  /// 请求客户端
  late final BtrBangumi client;

  /// 基础 URL
  final String baseUrl = 'https://api.bgm.tv';

  /// 数据库
  final BtsBangumiUser sqlite = BtsBangumiUser();

  /// access token
  static late String accessToken = '';

  /// 构造函数
  BtrBangumiApi() {
    client = BtrBangumi();
    client.dio.options.baseUrl = baseUrl;
  }

  /// 获取需要访问令牌的 header 项
  Future<Map<String, dynamic>> getAuthHeader() async {
    if (accessToken == '') {
      await refreshGetAccessToken();
    }
    return {
      ...client.dio.options.headers,
      'Authorization': 'Bearer $accessToken',
    };
  }

  /// 尝试获取访问令牌
  Future<void> refreshGetAccessToken({String? token}) async {
    if (token != null) {
      accessToken = token;
      return;
    }
    var atRead = await sqlite.readAccessToken();
    if (atRead != null) {
      accessToken = atRead;
    }
  }

  /// 条目模块

  /// 每日放送
  Future<BTResponse> getToday() async {
    try {
      var response = await client.dio.get('/calendar');
      if (response.statusCode == 200) {
        assert(response.data is List);
        var data = response.data as List;
        var list = data
            .map(
              (e) => BangumiCalendarRespData.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList();
        return BangumiCalendarResp.success(data: list);
      }
      var errResp = BangumiErrorDetail.fromJson(response.data);
      return BTResponse<BangumiErrorDetail>(
        code: response.statusCode ?? 666,
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

  /// 获取番剧详情
  Future<BTResponse> getSubjectDetail(String id) async {
    try {
      var authHeader = await getAuthHeader();
      var resp = await client.dio.get(
        '/v0/subjects/$id',
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      debugPrint('data: ${resp.data}');
      assert(resp.data is Map<String, dynamic>);
      return BangumiSubjectResp.success(
        data: BangumiSubject.fromJson(resp.data),
      );
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
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

  /// 章节模块

  /// 获取某条目的章节信息
  Future<BTResponse> getEpisodeList(
    int id, {
    BangumiLegacyEpisodeType? type,
    int? limit,
    int? offset,
  }) async {
    try {
      var authHeader = await getAuthHeader();
      var resp = await client.dio.get(
        '/v0/episodes',
        queryParameters: {
          'subject_id': id,
          'type': type?.value,
          'limit': limit,
          'offset': offset,
        },
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      var dataList = BangumiPageT<BangumiEpisode>.fromJson(
        resp.data as Map<String, dynamic>,
        (e) => BangumiEpisode.fromJson(
          e as Map<String, dynamic>,
        ),
      );
      debugPrint(dataList.data.map((e) => e.toJson()).toList().toString());
      return BangumiEpisodeListResp.success(data: dataList);
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
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
      var authHeader = await getAuthHeader();
      var resp = await client.dio.get(
        '/v0/me',
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      debugPrint('data: ${resp.data}');
      assert(resp.data is Map<String, dynamic>);
      return BangumiUserInfoResp.success(
        data: BangumiUser.fromJson(resp.data),
      );
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
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
    try {
      var authHeader = await getAuthHeader();
      var resp = await client.dio.get(
        '/v0/users/$username/collections',
        queryParameters: {
          'username': username,
          'subject_type': subjectType?.value,
          'type': collectionType?.value,
          'limit': limit,
          'offset': offset,
        },
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
      var authHeader = await getAuthHeader();
      var resp = await client.dio.get(
        '/v0/users/$username/collections/$subjectId',
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      debugPrint('data: ${resp.data}');
      assert(resp.data is Map<String, dynamic>);
      return BangumiCollectionSubjectItemResp.success(
        data: BangumiUserSubjectCollection.fromJson(resp.data),
      );
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      return BTResponse<BangumiErrorDetail>(
        code: e.response?.statusCode ?? 666,
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

  /// 获取用户章节收藏
  Future<BTResponse> getCollectionEpisodes(
    int subjectId, {
    int? offset,
    int? limit,
    BangumiLegacyEpisodeType? type,
  }) async {
    try {
      var authHeader = await getAuthHeader();
      var resp = await client.dio.get(
        '/v0/users/-/collections/$subjectId/episodes',
        queryParameters: {
          'subject_id': subjectId,
          'type': type?.value,
          'limit': limit,
          'offset': offset,
        },
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
      var authHeader = await getAuthHeader();
      var resp = await client.dio.get(
        '/v0/users/-/collections/-/episodes/$episodeId',
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      debugPrint('data: ${resp.data}');
      assert(resp.data is Map<String, dynamic>);
      return BangumiCollectionEpisodeItemResp.success(
        data: BangumiUserEpisodeCollection.fromJson(resp.data),
      );
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
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

  /// 更新用户单个收藏信息
  Future<BTResponse> updateCollectionEpisode({
    required BangumiEpisodeCollectionType type,
    required int episode,
  }) async {
    try {
      var authHeader = await getAuthHeader();
      var resp = await client.dio.put(
        '/v0/users/-/collections/-/episodes/$episode',
        queryParameters: {
          'episode_id': episode,
        },
        data: {
          'type': type.value,
        },
        options: Options(headers: authHeader, contentType: 'application/json'),
      );
      debugPrint('data: ${resp.data}');
      return BTResponse.success(data: null);
    } on DioException catch (e) {
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to update user collection episode item',
        data: null,
      );
    } on Exception catch (e) {
      return BTResponse.error(
        code: 666,
        message: 'Failed to update user collection episode item',
        data: e.toString(),
      );
    }
  }
}
