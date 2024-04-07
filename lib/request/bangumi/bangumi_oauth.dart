import 'package:url_launcher/url_launcher.dart';

import '../../models/app/err.dart';
import '../../models/bangumi/oauth.dart';
import '../../utils/get_bgm_secret.dart';
import '../core/client.dart';

/// bangumi.tv 的 OAuth
/// 参考: https://github.com/bangumi/api/blob/master/docs-raw/How-to-Auth.md
class BangumiOauth {
  /// 请求客户端
  late final BTRequestClient client;

  /// 基础 url
  final String baseUrl = 'https://bgm.tv/oauth';

  /// 构造函数
  BangumiOauth() {
    client = BTRequestClient();
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
  Future<BangumiTokenGResponse> getAccessToken(String code) async {
    var appId = getBgmAppId();
    var appSecret = getBgmAppSecret();
    var params = BangumiTokenGParams(
      appId: appId,
      appSecret: appSecret,
      code: code,
      state: '',
    );
    var response =
        await client.dio.post('/access_token', data: params.toJson());
    if (response.statusCode == 200) {
      return BangumiTokenGResponse.fromJson(
          response.data as Map<String, dynamic>);
    } else {
      throw BTError.requestError(msg: 'Failed to get bangumi access token');
    }
  }

  /// 刷新 AccessToken
  Future<BangumiTokenRResponse> refreshToken(String refreshToken) async {
    var appId = getBgmAppId();
    var appSecret = getBgmAppSecret();
    var params = BangumiTokenRParams(
      appId: appId,
      appSecret: appSecret,
      refreshToken: refreshToken,
    );
    var response =
        await client.dio.post('/access_token', data: params.toJson());
    if (response.statusCode == 200) {
      return BangumiTokenRResponse.fromJson(
          response.data as Map<String, dynamic>);
    } else {
      throw BTError.requestError(msg: 'Failed to refresh bangumi access token');
    }
  }

  /// 查询授权信息
  Future<BangumiTokenSResponse> getStatus(String accessToken) async {
    var response = await client.dio.get('/token_status', queryParameters: {
      'access_token': accessToken,
    });
    if (response.statusCode == 200) {
      return BangumiTokenSResponse.fromJson(
          response.data as Map<String, dynamic>);
    } else {
      throw BTError.requestError(msg: 'Failed to query bangumi access token');
    }
  }
}
