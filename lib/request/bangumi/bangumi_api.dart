import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';

import '../../database/bangumi/bangumi_user.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_subject.dart';
import '../../models/bangumi/user_request.dart';
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

  /// 需要访问令牌的请求
  Future<Response<T>> getWithAuth<T>(String path) async {
    if (accessToken == '') {
      await refreshGetAccessToken();
    }
    return client.dio.get<T>(
      path,
      options: Options(
        headers: {
          ...client.dio.options.headers,
          'Authorization': 'Bearer $accessToken'
        },
        contentType: 'application/json',
      ),
    );
  }

  /// 需要访问令牌的请求
  Future<Response<T>> postWithAuth<T>(String path, {dynamic data}) async {
    if (accessToken == '') {
      await refreshGetAccessToken();
    }
    return client.dio.post<T>(
      path,
      data: data,
      options: Options(
        headers: {'Authorization': 'Bearer $accessToken'},
        contentType: 'application/json',
      ),
    );
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
            .map((e) => BangumiCalendarRespData.fromJson(
                  e as Map<String, dynamic>,
                ))
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
  Future<BTResponse> getDetail(String id) async {
    try {
      var response = await getWithAuth('/v0/subjects/$id');
      if (response.statusCode == 200) {
        debugPrint('data: ${response.data}');
        assert(response.data is Map<String, dynamic>);
        return BangumiSubjectResp.success(
          data: BangumiSubject.fromJson(response.data),
        );
      } else {
        var errResp = BangumiErrorDetail.fromJson(response.data);
        return BTResponse<BangumiErrorDetail>(
          code: response.statusCode ?? 666,
          message: 'Failed to load detail',
          data: errResp,
        );
      }
    } on Exception catch (e) {
      BTLogTool.error('Failed to load detail: $e');
      return BTResponse.error(
        code: 666,
        message: 'Failed to load detail',
        data: null,
      );
    }
  }

  /// 获取用户信息
  Future<BTResponse> getUserInfo() async {
    var response = await getWithAuth(
      '/v0/me',
    );
    if (response.statusCode == 200) {
      debugPrint('data: ${response.data}');
      assert(response.data is Map<String, dynamic>);
      return BangumiUserInfoResponse.success(
        data: BangumiUserInfo.fromJson(response.data),
      );
    }
    try {
      var errResp = BangumiErrorDetail.fromJson(response.data);
      return BTResponse<BangumiErrorDetail>(
        code: response.statusCode ?? 666,
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
}
