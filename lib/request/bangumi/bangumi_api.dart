import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';

import '../../database/bangumi/bangumi_user.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_collection.dart';
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
  Future<BTResponse> getUserCollections({
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
      return BangumiCollectionListResp.success(data: dataList);
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
  Future<BTResponse> getUserCollectionItem(
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
      return BangumiCollectionItemResp.success(
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
}
