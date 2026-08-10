// Dart imports:
import 'dart:io';

// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/constants/app_constants.dart';
import 'package:bangumi_today/request/bangumi/bangumi_api.dart';
import 'package:bangumi_today/request/bangumi/bangumi_error_handler.dart';
import 'package:bangumi_today/request/bangumi/bangumi_oauth.dart';

void main() {
  group('BtrBangumiApi base URL', () {
    tearDown(() {
      BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiApiBaseUrl);
    });

    test('defaults to the AniBT mirror', () {
      expect(BtrBangumiApi.baseUrl, BTAppConstants.bangumiApiBaseUrl);
    });

    test('removes trailing slashes', () {
      BtrBangumiApi.setBaseUrl('https://api.bgm.tv///');

      expect(BtrBangumiApi.baseUrl, 'https://api.bgm.tv');
    });

    test('falls back to the default for an empty URL', () {
      BtrBangumiApi.setBaseUrl('   ');

      expect(BtrBangumiApi.baseUrl, BTAppConstants.bangumiApiBaseUrl);
    });
  });

  group('BtrBangumiApi domain rewriting', () {
    tearDown(() {
      BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiApiBaseUrl);
    });

    test('rewrites site and image URLs for the AniBT mirror', () {
      BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiApiBaseUrl);

      expect(
        BtrBangumiApi.rewriteUrl('http://bgm.tv/subject/1'),
        'https://bgmmi.anibt.net/subject/1',
      );
      expect(
        BtrBangumiApi.rewriteUrl('http://lain.bgm.tv/pic/cover.jpg'),
        'https://bgmimg.anibt.net/pic/cover.jpg',
      );
    });

    test('rewrites every supported official domain for bangumi.lol', () {
      BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiLolApiBaseUrl);

      var mappings = {
        'https://bgm.tv/subject/1': 'https://bangumi.lol/subject/1',
        'https://api.bgm.tv/v0/me': 'https://api.bangumi.lol/v0/me',
        'https://lain.bgm.tv/pic/a.jpg': 'https://lain.bangumi.lol/pic/a.jpg',
        'https://fast.bgm.tv/a': 'https://fast.bangumi.lol/a',
        'https://next.bgm.tv/a': 'https://next.bangumi.lol/a',
        'https://doujin.bgm.tv/a': 'https://doujin.bangumi.lol/a',
      };

      for (var entry in mappings.entries) {
        expect(BtrBangumiApi.rewriteUrl(entry.key), entry.value);
      }
    });

    test('preserves typed JSON maps while rewriting nested URLs', () {
      BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiApiBaseUrl);
      var data = <String, dynamic>{
        'url': 'http://bgm.tv/subject/1',
        'images': <String, dynamic>{'small': 'http://lain.bgm.tv/pic/a.jpg'},
      };

      var rewritten = BtrBangumiApi.rewriteResponseData(data);

      expect(rewritten, isA<Map<String, dynamic>>());
      expect(rewritten['url'], 'https://bgmmi.anibt.net/subject/1');
      expect(
        rewritten['images']['small'],
        'https://bgmimg.anibt.net/pic/a.jpg',
      );
    });
  });

  group('handleBangumiDioException', () {
    test('handles a handshake failure without response data', () {
      var exception = DioException(
        requestOptions: RequestOptions(
          path: '/v0/me',
          baseUrl: 'https://bgmapi.anibt.net',
        ),
        type: DioExceptionType.unknown,
        error: const HandshakeException('Connection terminated'),
      );

      var response = handleBangumiDioException(
        exception,
        fallbackMessage: 'Failed to load user info',
      );

      expect(response.code, 666);
      expect(response.message, contains('HandshakeException'));
      expect(response.data, isNull);
    });

    test('uses API error descriptions when a response exists', () {
      var requestOptions = RequestOptions(path: '/v0/me');
      var exception = DioException.badResponse(
        statusCode: 401,
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 401,
          data: {'description': 'Unauthorized'},
        ),
      );

      var response = handleBangumiDioException(
        exception,
        fallbackMessage: 'Failed to load user info',
      );

      expect(response.code, 401);
      expect(response.message, 'Unauthorized');
      expect(response.data, isNull);
    });

    test('maps cancelled requests to status 499', () {
      var exception = DioException.requestCancelled(
        requestOptions: RequestOptions(path: '/calendar'),
        reason: 'cancelled',
      );

      var response = handleBangumiDioException(
        exception,
        fallbackMessage: 'Failed to load today',
      );

      expect(response.code, 499);
      expect(response.message, 'Request cancelled');
      expect(response.data, isNull);
    });
  });

  test('handles an unexpected successful response format', () {
    var requestOptions = RequestOptions(
      path: '/v0/subjects/1',
      baseUrl: BTAppConstants.bangumiApiBaseUrl,
    );
    var response = Response(
      requestOptions: requestOptions,
      statusCode: 200,
      data: '<html>unexpected response</html>',
    );

    var result = handleBangumiUnexpectedResponse(
      response,
      fallbackMessage: 'Failed to load subject detail',
    );

    expect(result.code, 502);
    expect(result.message, contains('Unexpected response format'));
    expect(result.data, isNull);
  });

  group('BtrBangumiOauth base URL', () {
    tearDown(() {
      BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiApiBaseUrl);
    });

    test('uses the site mirror paired with the API mirror', () {
      BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiApiBaseUrl);

      expect(
        BtrBangumiOauth.oauthBaseUrl,
        '${BTAppConstants.bangumiSiteBaseUrl}/oauth',
      );
    });

    test('uses the official OAuth URL with the official API', () {
      BtrBangumiApi.setBaseUrl(BTAppConstants.officialBangumiApiBaseUrl);

      expect(
        BtrBangumiOauth.oauthBaseUrl,
        '${BTAppConstants.officialBangumiSiteBaseUrl}/oauth',
      );
    });

    test('uses bangumi.lol OAuth with the bangumi.lol API', () {
      BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiLolApiBaseUrl);

      expect(
        BtrBangumiOauth.oauthBaseUrl,
        '${BTAppConstants.bangumiLolSiteBaseUrl}/oauth',
      );
    });
  });
}
