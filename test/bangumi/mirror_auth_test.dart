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
  late String originalSiteUrl;
  late String originalImageUrl;

  void selectMirrors(String apiUrl) {
    BtrBangumiApi.setBaseUrl(apiUrl);
    BtrBangumiApi.setSiteBaseUrl(BTAppConstants.bangumiSiteBaseUrlFor(apiUrl));
    BtrBangumiApi.setImageBaseUrl(
      BTAppConstants.bangumiImageBaseUrlFor(apiUrl),
    );
  }

  setUp(() {
    originalBaseUrl = BtrBangumiApi.baseUrl;
    originalSiteUrl = BtrBangumiApi.siteBaseUrl;
    originalImageUrl = BtrBangumiApi.imageBaseUrl;
  });
  tearDown(() {
    BtrBangumiApi.setBaseUrl(originalBaseUrl);
    BtrBangumiApi.setSiteBaseUrl(originalSiteUrl);
    BtrBangumiApi.setImageBaseUrl(originalImageUrl);
  });

  test('saved PRO selections migrate to VIP after URL normalization', () {
    selectMirrors('  https://api.bangumi.pro/  ');

    expect(BtrBangumiApi.baseUrl, 'https://api.bangumi.vip');
    expect(BtrBangumiApi.siteBaseUrl, 'https://bangumi.vip');
    expect(BtrBangumiApi.imageBaseUrl, 'https://lain.bangumi.vip');
    expect(BtrBangumiApi.nextBaseUrl, 'https://next.bangumi.vip');
  });

  test(
    'cached PRO links migrate without losing paths, queries or fragments',
    () {
      selectMirrors('https://api.bangumi.vip');

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
    'saved official selections migrate to bgmapi and rewrite cached VIP links',
    () {
      selectMirrors('  https://api.bgm.tv/  ');

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
    'OAuth login stays on the site host and token calls on the API host',
    () async {
      selectMirrors(BTAppConstants.bangumiVipApiBaseUrl);
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

      expect(BtrBangumiOauth.oauthAuthorizeBaseUrl, 'https://bgm.tv/oauth');
      expect(BtrBangumiOauth.oauthBaseUrl, 'https://api.bgmapi.com/oauth');
      BtrBangumiApi.setBaseUrl(BTAppConstants.officialBangumiApiBaseUrl);
      expect(BtrBangumiOauth.oauthAuthorizeBaseUrl, 'https://bgm.tv/oauth');
      expect(BtrBangumiOauth.oauthBaseUrl, 'https://api.bgmapi.com/oauth');
      await oauth.client.dio.post('/access_token');
      BtrBangumiApi.setBaseUrl(BTAppConstants.anibtBangumiApiBaseUrl);
      BtrBangumiApi.setSiteBaseUrl(BTAppConstants.officialBangumiSiteBaseUrl);
      expect(BtrBangumiOauth.oauthAuthorizeBaseUrl, 'https://bgm.tv/oauth');
      expect(BtrBangumiOauth.oauthBaseUrl, 'https://api.bgmapi.com/oauth');
      await oauth.client.dio.post('/access_token');
      BtrBangumiApi.setSiteBaseUrl(BTAppConstants.anibtBangumiSiteBaseUrl);
      BtrBangumiApi.setImageBaseUrl(BTAppConstants.anibtBangumiImageBaseUrl);
      expect(BtrBangumiOauth.oauthAuthorizeBaseUrl, 'https://bgm.tv/oauth');
      expect(BtrBangumiOauth.oauthBaseUrl, 'https://api.bgmapi.com/oauth');
      await oauth.client.dio.post('/access_token');

      expect(requests.map((uri) => uri.toString()), [
        'https://api.bgmapi.com/oauth/access_token',
        'https://api.bgmapi.com/oauth/access_token',
        'https://api.bgmapi.com/oauth/access_token',
      ]);
    },
  );

  test(
    'legacy token status stays on the official host with mirrors selected',
    () async {
      selectMirrors(BTAppConstants.anibtBangumiApiBaseUrl);
      BtrBangumiApi.setSiteBaseUrl(BTAppConstants.bangumiVipSiteBaseUrl);
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

  test('all site, API and image mirror combinations rewrite independently', () {
    const apiUrls = [
      BTAppConstants.officialBangumiApiBaseUrl,
      BTAppConstants.bangumiVipApiBaseUrl,
      BTAppConstants.anibtBangumiApiBaseUrl,
    ];
    const siteUrls = [
      BTAppConstants.officialBangumiSiteBaseUrl,
      BTAppConstants.bangumiVipSiteBaseUrl,
      BTAppConstants.anibtBangumiSiteBaseUrl,
    ];
    const imageUrls = [
      BTAppConstants.officialBangumiImageBaseUrl,
      BTAppConstants.bangumiVipImageBaseUrl,
      BTAppConstants.anibtBangumiImageBaseUrl,
    ];
    for (var api in apiUrls) {
      for (var site in siteUrls) {
        for (var image in imageUrls) {
          BtrBangumiApi.setBaseUrl(api);
          BtrBangumiApi.setSiteBaseUrl(site);
          BtrBangumiApi.setImageBaseUrl(image);
          expect(
            BtrBangumiApi.rewriteUrl(
              'https://api.bgm.tv/v0/subjects/876?x=1#section',
            ),
            '$api/v0/subjects/876?x=1#section',
          );
          expect(
            BtrBangumiApi.rewriteUrl('https://bangumi.vip/subject/876'),
            '$site/subject/876',
          );
          expect(
            BtrBangumiApi.rewriteUrl('https://bgmimg.anibt.net/pic/test.jpg'),
            '$image/pic/test.jpg',
          );
          expect(
            BtrBangumiApi.nextBaseUrl,
            api == BTAppConstants.bangumiVipApiBaseUrl
                ? BTAppConstants.bangumiVipNextBaseUrl
                : BTAppConstants.officialBangumiNextBaseUrl,
          );
          expect(
            BtrBangumiApi.rewriteUrl('https://example.test/pic/test.jpg'),
            'https://example.test/pic/test.jpg',
          );
        }
      }
    }
  });

  test('changing one mirror leaves the other two selections intact', () {
    selectMirrors(BTAppConstants.officialBangumiApiBaseUrl);
    BtrBangumiApi.setSiteBaseUrl('  https://bgmmi.anibt.net/  ');
    expect(BtrBangumiApi.baseUrl, BTAppConstants.officialBangumiApiBaseUrl);
    expect(
      BtrBangumiApi.imageBaseUrl,
      BTAppConstants.officialBangumiImageBaseUrl,
    );
    BtrBangumiApi.setImageBaseUrl('  https://lain.bangumi.pro/  ');
    expect(BtrBangumiApi.baseUrl, BTAppConstants.officialBangumiApiBaseUrl);
    expect(BtrBangumiApi.siteBaseUrl, BTAppConstants.anibtBangumiSiteBaseUrl);
    BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiVipApiBaseUrl);
    expect(BtrBangumiApi.siteBaseUrl, BTAppConstants.anibtBangumiSiteBaseUrl);
    expect(BtrBangumiApi.imageBaseUrl, BTAppConstants.bangumiVipImageBaseUrl);
  });

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
