// Package imports:
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

// Project imports:
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/bangumi_oauth_model.dart';
import '../../tools/log_tool.dart';
import '../../utils/bangumi_utils.dart';
import '../core/client.dart';

/// bangumi.tv 的 OAuth
/// 参考: https://github.com/bangumi/api/blob/master/docs-raw/How-to-Auth.md
class BtrBangumiOauth {
  /// 请求客户端
  late final BtrClient client;

  /// 基础 url
  final String baseUrl = 'https://bgm.tv/oauth';

  /// 构造函数
  BtrBangumiOauth() {
    client = BtrClient.withHeader();
    client.dio.options.baseUrl = baseUrl;
  }

  /// 打开授权页面
  Future<void> openAuthorizePage() async {
    // todo 前置判断是否已经授权
    var appId = getBgmAppId();
    var params = BangumiOauthParams(appId: appId);
    var url = Uri(
      scheme: 'https',
      host: 'bgm.tv',
      path: '/oauth/authorize',
      queryParameters: params.toJson(),
    );
    await launchUrl(url);
  }

  /// 获取 AccessToken
  Future<BTResponse> getAccessToken(String code) async {
    var appId = getBgmAppId();
    var appSecret = getBgmAppSecret();
    var params = BangumiOauthTokenGetParams(
      appId: appId,
      appSecret: appSecret,
      code: code,
      state: '',
    );
    try {
      var response = await client.dio.post(
        '/access_token',
        data: params.toJson(),
      );
      assert(response.data is Map<String, dynamic>);
      return BangumiOauthTokenGetResp.success(
        data: BangumiOauthTokenGetData.fromJson(response.data),
      );
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error('Failed to load bangumi token get: $errResp');
      return BTResponse<BangumiErrorDetail>(
        code: e.response?.statusCode ?? 666,
        message: 'Bangumi token get error',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to load bangumi token get: $e');
      return BTResponse.error(
        code: 666,
        message: 'Bangumi token get error',
        data: null,
      );
    }
  }

  /// 刷新 AccessToken
  Future<BTResponse> refreshToken(String refreshToken) async {
    var appId = getBgmAppId();
    var appSecret = getBgmAppSecret();
    var params = BangumiOauthTokenRefreshParams(
      appId: appId,
      appSecret: appSecret,
      refreshToken: refreshToken,
    );
    try {
      var response = await client.dio.post(
        '/access_token',
        data: params.toJson(),
      );
      assert(response.data is Map<String, dynamic>);
      return BangumiOauthTokenRefreshResp.success(
        data: BangumiOauthTokenRefreshData.fromJson(response.data),
      );
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error('Failed to load bangumi token refresh: $errResp');
      return BTResponse<BangumiErrorDetail>(
        code: e.response?.statusCode ?? 666,
        message: 'Bangumi token refresh error',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to load bangumi token refresh: $e');
      return BTResponse.error(
        code: 666,
        message: 'Bangumi token refresh error',
        data: e.toString(),
      );
    }
  }

  /// 查询授权信息
  Future<BTResponse> getStatus(String accessToken) async {
    try {
      var response = await client.dio.get('/token_status', queryParameters: {
        'access_token': accessToken,
      });
      assert(response.data is Map<String, dynamic>);
      return BangumiOauthTokenStatusResp.success(
        data: BangumiOauthTokenStatusData.fromJson(
          response.data as Map<String, dynamic>,
        ),
      );
    } on DioException catch (e) {
      var errResp = BangumiErrorDetail.fromJson(e.response?.data);
      BTLogTool.error('Failed to load bangumi token status: $errResp');
      return BTResponse<BangumiErrorDetail>(
        code: e.response?.statusCode ?? 666,
        message: 'Bangumi token status error',
        data: errResp,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to load bangumi token status: $e');
      return BTResponse.error(
        code: 666,
        message: 'Bangumi token status error',
        data: null,
      );
    }
  }
}
