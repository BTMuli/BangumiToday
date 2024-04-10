import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';

import '../../database/bangumi/bangumi_user.dart';
import '../../models/app/err.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/common_response.dart';
import '../../models/bangumi/get_calendar.dart';
import '../../models/bangumi/get_subject.dart';
import '../../models/bangumi/user_request.dart';
import '../../tools/log_tool.dart';
import 'bangumi_client.dart';

/// bangumi.tv 的 API
/// 详细文档请参考 https://bangumi.github.io/api/
class BangumiAPI {
  /// 请求客户端
  late final BangumiClient client;

  /// 基础 URL
  final String baseUrl = 'https://api.bgm.tv';

  /// 数据库
  final BtsBangumiUser sqlite = BtsBangumiUser();

  /// access token
  static late String accessToken = '';

  /// 构造函数
  BangumiAPI() {
    client = BangumiClient();
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
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
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
  Future<List<CalendarItem>> getToday() async {
    var response = await client.dio.get('/calendar');
    if (response.statusCode == 200) {
      return (response.data as List)
          .map((e) => CalendarItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw BTError.requestError(msg: 'Failed to load today');
    }
  }

  /// 获取番剧详情
  Future<BangumiSubject> getDetail(String id) async {
    var response = await getWithAuth('/v0/subjects/$id');
    if (response.statusCode == 200) {
      debugPrint('data: ${response.data}');
      return BangumiSubject.fromJson(response.data as Map<String, dynamic>);
    } else {
      throw BTError.requestError(msg: 'Failed to load detail');
    }
  }

  /// 获取用户信息
  Future<BTResponse> getUserInfo() async {
    var response = await getWithAuth(
      '/v0/me',
    );
    if (response.statusCode == 200) {
      debugPrint('data: ${response.data}');
      return BangumiUserInfoResponse.success(
        data: BangumiUserInfo.fromJson(response.data as Map<String, dynamic>),
      );
    }
    try {
      var errResp = BangumiErrResponse.fromJson(response.data);
      return BTResponse<BangumiErrResponse>(
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
