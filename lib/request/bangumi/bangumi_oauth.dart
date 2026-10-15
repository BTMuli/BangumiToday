// Package imports:
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

// Project imports:
import '../../core/constants/app_constants.dart';
import '../../core/utils/bangumi_utils.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_oauth_model.dart';
import '../../tools/log_tool.dart';
import '../core/client.dart';
import 'bangumi_api.dart';
import 'bangumi_error_handler.dart';

/// OAuth 授权网关抽象，便于测试注入可控实现。
abstract class BangumiOauthGateway {
  /// 打开授权页面。
  Future<void> openAuthorizePage({String? state});

  /// 用授权码换取 AccessToken。
  Future<BTResponse> getAccessToken(
    String code, {
    String? state,
    CancelToken? cancelToken,
  });
}

/// bangumi.tv 的 OAuth
/// 参考: https://github.com/bangumi/api/blob/master/docs-raw/How-to-Auth.md
class BtrBangumiOauth implements BangumiOauthGateway {
  /// 请求客户端
  late final BtrClient client;

  /// 当前站点 URL
  static String get siteBaseUrl => BtrBangumiApi.siteBaseUrl;

  /// bgmapi 同时提供 OAuth；其余授权页跟随所选站点。
  static String get oauthBaseUrl =>
      BtrBangumiApi.baseUrl == BTAppConstants.bgmApiBaseUrl
      ? '${BTAppConstants.bgmApiBaseUrl}/oauth'
      : '$siteBaseUrl/oauth';

  /// bgmapi 的 token 请求走同域 OAuth；网页镜像仍优先走官方站。
  static String get oauthTokenBaseUrl =>
      BtrBangumiApi.baseUrl == BTAppConstants.bgmApiBaseUrl
      ? oauthBaseUrl
      : '${BTAppConstants.officialBangumiSiteBaseUrl}/oauth';

  /// 构造函数
  BtrBangumiOauth() {
    client = BtrClient.withHeader();
    client.dio.options.baseUrl = oauthBaseUrl;
    client.dio.interceptors.insert(0, _BangumiOauthBaseUrlInterceptor());
  }

  /// 打开授权页面
  @override
  Future<void> openAuthorizePage({String? state}) async {
    if (!hasBgmOauthCredentials()) {
      throw StateError(bgmOauthCredentialsMissing);
    }
    var appId = getBgmAppId();
    var params = BangumiOauthParams(appId: appId, state: state);
    var query = <String, String>{};
    params.toJson().forEach((key, value) {
      if (value != null) query[key] = value.toString();
    });
    var url = Uri.parse(
      '$oauthBaseUrl/authorize',
    ).replace(queryParameters: query);
    if (!await launchUrl(url)) {
      throw StateError('无法打开授权页面，请检查默认浏览器设置后重试');
    }
  }

  /// 获取 AccessToken
  @override
  Future<BTResponse> getAccessToken(
    String code, {
    String? state,
    CancelToken? cancelToken,
  }) async {
    if (!hasBgmOauthCredentials()) {
      return BTResponse.error(
        code: 500,
        message: bgmOauthCredentialsMissing,
        data: null,
      );
    }
    var appId = getBgmAppId();
    var appSecret = getBgmAppSecret();
    var params = BangumiOauthTokenGetParams(
      appId: appId,
      appSecret: appSecret,
      code: code,
      state: state,
    );
    try {
      var payload = _oauthForm(params.toJson());
      var response = await _postOauthForm(
        '/access_token',
        payload,
        cancelToken: cancelToken,
      );
      var map = bangumiJsonMap(response.data);
      if (map == null) {
        return handleBangumiUnexpectedResponse(
          response,
          fallbackMessage: 'Bangumi token get error',
        );
      }
      var oauthError = readBangumiOauthError(
        map,
        fallbackMessage: 'Bangumi token get error',
      );
      if (oauthError != null) return oauthError;
      return BangumiOauthTokenGetResp.success(
        data: BangumiOauthTokenGetData.fromJson(map),
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
    if (!hasBgmOauthCredentials()) {
      return BTResponse.error(
        code: 500,
        message: bgmOauthCredentialsMissing,
        data: null,
      );
    }
    var appId = getBgmAppId();
    var appSecret = getBgmAppSecret();
    var params = BangumiOauthTokenRefreshParams(
      appId: appId,
      appSecret: appSecret,
      refreshToken: refreshToken,
    );
    try {
      var payload = _oauthForm(params.toJson());
      var response = await _postOauthForm('/access_token', payload);
      var map = bangumiJsonMap(response.data);
      if (map == null) {
        return handleBangumiUnexpectedResponse(
          response,
          fallbackMessage: 'Bangumi token refresh error',
        );
      }
      var oauthError = readBangumiOauthError(
        map,
        fallbackMessage: 'Bangumi token refresh error',
      );
      if (oauthError != null) return oauthError;
      return BangumiOauthTokenRefreshResp.success(
        data: BangumiOauthTokenRefreshData.fromJson(map),
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
      // bgmapi 的新版 OAuth 未提供旧版 token_status 接口。
      var response = await _postOauthForm(
        '/token_status',
        {'access_token': accessToken},
        useOfficialSite: BtrBangumiApi.baseUrl == BTAppConstants.bgmApiBaseUrl,
      );
      var map = bangumiJsonMap(response.data);
      if (map == null) {
        return handleBangumiUnexpectedResponse(
          response,
          fallbackMessage: 'Bangumi token status error',
        );
      }
      var oauthError = readBangumiOauthError(
        map,
        fallbackMessage: 'Bangumi token status error',
      );
      if (oauthError != null) return oauthError;
      return BangumiOauthTokenStatusResp.success(
        data: BangumiOauthTokenStatusData.fromJson(map),
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

  Map<String, String> _oauthForm(Map<String, dynamic> data) {
    var payload = <String, String>{};
    data.forEach((key, value) {
      if (value != null) payload[key] = value.toString();
    });
    return payload;
  }

  Future<Response<dynamic>> _postOauthForm(
    String path,
    Map<String, String> payload, {
    bool useSelectedSite = false,
    bool useOfficialSite = false,
    CancelToken? cancelToken,
  }) async {
    var options = Options(
      contentType: Headers.formUrlEncodedContentType,
      extra: {
        if (useSelectedSite) 'oauthUseSelectedSite': true,
        if (useOfficialSite) 'oauthUseOfficialSite': true,
      },
    );
    var response = await client.dio.post(
      path,
      data: payload,
      options: options,
      cancelToken: cancelToken,
    );
    if (bangumiJsonMap(response.data) != null ||
        useSelectedSite ||
        useOfficialSite) {
      return response;
    }
    if (oauthBaseUrl == oauthTokenBaseUrl) return response;
    BTLogTool.warn('官方 OAuth $path 非 JSON，改走 $oauthBaseUrl');
    return _postOauthForm(
      path,
      payload,
      useSelectedSite: true,
      cancelToken: cancelToken,
    );
  }
}

class _BangumiOauthBaseUrlInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    var useSelectedSite = options.extra['oauthUseSelectedSite'] == true;
    options.baseUrl = options.extra['oauthUseOfficialSite'] == true
        ? '${BTAppConstants.officialBangumiSiteBaseUrl}/oauth'
        : useSelectedSite
        ? BtrBangumiOauth.oauthBaseUrl
        : BtrBangumiOauth.oauthTokenBaseUrl;
    handler.next(options);
  }
}
