// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Project imports:
import 'package:bangumi_today/core/constants/app_constants.dart';
import 'package:bangumi_today/models/bangumi/bangumi_oauth_model.dart';
import 'package:bangumi_today/request/bangumi/bangumi_api.dart';
import 'package:bangumi_today/request/bangumi/bangumi_oauth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'BangumiToday',
    packageName: 'bangumi_today',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );

  late String originalBaseUrl;

  setUp(() => originalBaseUrl = BtrBangumiApi.baseUrl);
  tearDown(() => BtrBangumiApi.setBaseUrl(originalBaseUrl));

  test('saved PRO selections migrate to VIP after URL normalization', () {
    BtrBangumiApi.setBaseUrl('  https://api.bangumi.pro/  ');

    expect(BtrBangumiApi.baseUrl, 'https://api.bangumi.vip');
    expect(BtrBangumiApi.siteBaseUrl, 'https://bangumi.vip');
    expect(BtrBangumiApi.imageBaseUrl, 'https://lain.bangumi.vip');
    expect(BtrBangumiApi.nextBaseUrl, 'https://next.bangumi.vip');
  });

  test(
    'cached PRO links migrate without losing paths, queries or fragments',
    () {
      BtrBangumiApi.setBaseUrl('https://api.bangumi.vip');

      for (var prefix in ['', 'api.', 'lain.', 'fast.', 'next.', 'doujin.']) {
        expect(
          BtrBangumiApi.rewriteUrl(
            'https://${prefix}bangumi.pro/subject/876?x=1#section',
          ),
          'https://${prefix}bangumi.vip/subject/876?x=1#section',
        );
      }
    },
  );

  test(
    'switching to bgmapi rewrites cached VIP links to official web hosts',
    () {
      BtrBangumiApi.setBaseUrl(BTAppConstants.bgmApiBaseUrl);

      expect(BtrBangumiApi.baseUrl, 'https://api.bgmapi.com');
      expect(
        BtrBangumiApi.rewriteUrl('https://api.bangumi.vip/v0/subjects/876'),
        'https://api.bgmapi.com/v0/subjects/876',
      );
      expect(
        BtrBangumiApi.rewriteUrl('https://bangumi.vip/subject/876'),
        'https://bgm.tv/subject/876',
      );
      expect(
        BtrBangumiApi.rewriteUrl('https://lain.bangumi.vip/pic/test.jpg'),
        'https://lain.bgm.tv/pic/test.jpg',
      );
      expect(
        BtrBangumiApi.rewriteUrl('https://next.bangumi.pro/subject/876'),
        'https://next.bgm.tv/subject/876',
      );
    },
  );

  test(
    'an existing OAuth client follows the selected token endpoint',
    () async {
      BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiVipApiBaseUrl);
      var oauth = BtrBangumiOauth();
      addTearDown(() => oauth.client.dio.close(force: true));
      var requests = <Uri>[];
      oauth.client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options.uri);
            handler.resolve(Response(requestOptions: options, data: {}));
          },
        ),
      );

      expect(BtrBangumiOauth.oauthBaseUrl, 'https://bangumi.vip/oauth');
      await oauth.client.dio.post('/access_token');
      BtrBangumiApi.setBaseUrl(BTAppConstants.bgmApiBaseUrl);
      expect(BtrBangumiOauth.oauthBaseUrl, 'https://api.bgmapi.com/oauth');
      await oauth.client.dio.post('/access_token');
      BtrBangumiApi.setBaseUrl(BTAppConstants.anibtBangumiApiBaseUrl);
      await oauth.client.dio.post('/access_token');

      expect(requests.map((uri) => uri.toString()), [
        'https://bgm.tv/oauth/access_token',
        'https://api.bgmapi.com/oauth/access_token',
        'https://bgm.tv/oauth/access_token',
      ]);
    },
  );

  test(
    'bgmapi keeps legacy token status requests on the official host',
    () async {
      BtrBangumiApi.setBaseUrl(BTAppConstants.bgmApiBaseUrl);
      var oauth = BtrBangumiOauth();
      addTearDown(() => oauth.client.dio.close(force: true));
      Uri? requestedUri;
      oauth.client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedUri = options.uri;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'access_token': 'test-token',
                  'client_id': 'test-client',
                  'expires': 1800000000,
                  'user_id': 42,
                },
              ),
            );
          },
        ),
      );

      var response = await oauth.getStatus('test-token');

      expect(requestedUri.toString(), 'https://bgm.tv/oauth/token_status');
      expect(response.code, 0);
    },
  );

  test('token responses accept legacy and bgmapi user IDs', () {
    for (var userId in <Object>[42, '42']) {
      var token = BangumiOauthTokenGetData.fromJson({
        'access_token': 'test-token',
        'expires_in': 1209600,
        'token_type': 'Bearer',
        'refresh_token': 'test-refresh',
        'user_id': userId,
      });

      expect(token.userId, 42);
      expect(token.scope, isNull);
      expect(token.toJson()['user_id'], 42);
    }
  });
}
