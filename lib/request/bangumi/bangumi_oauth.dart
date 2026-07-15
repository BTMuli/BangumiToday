// Package imports:
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

// Project imports:
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_oauth_model.dart';
import '../../tools/log_tool.dart';
import '../../utils/bangumi_utils.dart';
import '../core/client.dart';
import 'bangumi_api.dart';
import 'bangumi_error_handler.dart';

/// bangumi.tv 的 OAuth
/// 参考: https://github.com/bangumi/api/blob/master/docs-raw/How-to-Auth.md
class BtrBangumiOauth {
  /// 请求客户端
  late final BtrClient client;

  /// 当前站点 URL
  static String get siteBaseUrl => BtrBangumiApi.siteBaseUrl;

  /// 当前 OAuth URL
  static String get oauthBaseUrl => '$siteBaseUrl/oauth';

  /// 构造函数
  BtrBangumiOauth() {
    client = BtrClient.withHeader();
    client.dio.options.baseUrl = oauthBaseUrl;
    client.dio.interceptors.insert(0, _BangumiOauthBaseUrlInterceptor());
  }

  /// 打开授权页面
  Future<void> openAuthorizePage() async {
    var appId = getBgmAppId();
    var params = BangumiOauthParams(appId: appId);
    var url = Uri.parse('$siteBaseUrl/oauth/authorize').replace(
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
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      if (response.data is! Map<String, dynamic>) {
        return handleBangumiUnexpectedResponse(
          response,
          fallbackMessage: 'Bangumi token get error',
        );
      }
      return BangumiOauthTokenGetResp.success(
        data: BangumiOauthTokenGetData.fromJson(response.data),
      );
    } on DioException catch (e) {
      return handleBangumiDioException(
        e,
        fallbackMessage: 'Bangumi token get error',
      );
    } catch (e) {
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
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      if (response.data is! Map<String, dynamic>) {
        return handleBangumiUnexpectedResponse(
          response,
          fallbackMessage: 'Bangumi token refresh error',
        );
      }
      return BangumiOauthTokenRefreshResp.success(
        data: BangumiOauthTokenRefreshData.fromJson(response.data),
      );
    } on DioException catch (e) {
      return handleBangumiDioException(
        e,
        fallbackMessage: 'Bangumi token refresh error',
      );
    } catch (e) {
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
      var response = await client.dio.post(
        '/token_status',
        data: {'access_token': accessToken},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      if (response.data is! Map<String, dynamic>) {
        return handleBangumiUnexpectedResponse(
          response,
          fallbackMessage: 'Bangumi token status error',
        );
      }
      return BangumiOauthTokenStatusResp.success(
        data: BangumiOauthTokenStatusData.fromJson(
          response.data as Map<String, dynamic>,
        ),
      );
    } on DioException catch (e) {
      return handleBangumiDioException(
        e,
        fallbackMessage: 'Bangumi token status error',
      );
    } catch (e) {
      BTLogTool.error('Failed to load bangumi token status: $e');
      return BTResponse.error(
        code: 666,
        message: 'Bangumi token status error',
        data: null,
      );
    }
  }
}

class _BangumiOauthBaseUrlInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.baseUrl = BtrBangumiOauth.oauthBaseUrl;
    handler.next(options);
  }
}
