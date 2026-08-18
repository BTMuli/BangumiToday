// Package imports:
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

// Project imports:
import '../../core/constants/app_constants.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_oauth_model.dart';
import '../../tools/log_tool.dart';
import '../../utils/bangumi_utils.dart';
import '../core/client.dart';
import 'bangumi_api.dart';
import 'bangumi_error_handler.dart';

/// OAuth 授权网关抽象，便于测试注入可控实现。
abstract class BangumiOauthGateway {
  /// 打开授权页面。
  Future<void> openAuthorizePage({String? state});

  /// 用授权码换取 AccessToken。
  Future<BTResponse> getAccessToken(String code, {String? state});
}

/// bangumi.tv 的 OAuth
/// 参考: https://github.com/bangumi/api/blob/master/docs-raw/How-to-Auth.md
class BtrBangumiOauth implements BangumiOauthGateway {
  /// 请求客户端
  late final BtrClient client;

  /// 当前站点 URL
  static String get siteBaseUrl => BtrBangumiApi.siteBaseUrl;

  /// 授权页跟随所选站点；浏览器可过镜像的 Cloudflare。
  static String get oauthBaseUrl => '$siteBaseUrl/oauth';

  /// 换 token 固定走官方站。bangumi.lol 的 mirrox 会把
  /// `POST /oauth/access_token` 拦成 HTML 400。
  static String get oauthTokenBaseUrl =>
      '${BTAppConstants.officialBangumiSiteBaseUrl}/oauth';

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
    await launchUrl(url);
  }

  /// 获取 AccessToken
  @override
  Future<BTResponse> getAccessToken(String code, {String? state}) async {
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
      var response = await _postOauthForm('/access_token', payload);
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
      var response = await _postOauthForm('/token_status', {
        'access_token': accessToken,
      });
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
  }) async {
    var options = Options(
      contentType: Headers.formUrlEncodedContentType,
      extra: {if (useSelectedSite) 'oauthUseSelectedSite': true},
    );
    var response = await client.dio.post(path, data: payload, options: options);
    if (bangumiJsonMap(response.data) != null || useSelectedSite) {
      return response;
    }
    if (oauthBaseUrl == oauthTokenBaseUrl) return response;
    BTLogTool.warn('官方 OAuth $path 非 JSON，改走 $oauthBaseUrl');
    return _postOauthForm(path, payload, useSelectedSite: true);
  }
}

class _BangumiOauthBaseUrlInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    var useSelectedSite = options.extra['oauthUseSelectedSite'] == true;
    options.baseUrl = useSelectedSite
        ? BtrBangumiOauth.oauthBaseUrl
        : BtrBangumiOauth.oauthTokenBaseUrl;
    handler.next(options);
  }
}
