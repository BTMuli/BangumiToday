import 'dart:io';

import 'package:bangumi_today/core/constants/app_constants.dart';
import 'package:bangumi_today/request/bangumi/bangumi_api.dart';
import 'package:bangumi_today/request/bangumi/bangumi_error_handler.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BtrBangumiApi base URL', () {
    tearDown(() {
      BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiApiBaseUrl);
    });

    test('defaults to bangumi.one', () {
      expect(
        BtrBangumiApi.baseUrl,
        BTAppConstants.bangumiApiBaseUrl,
      );
    });

    test('removes trailing slashes', () {
      BtrBangumiApi.setBaseUrl('https://api.bgm.tv///');

      expect(BtrBangumiApi.baseUrl, 'https://api.bgm.tv');
    });

    test('falls back to the default for an empty URL', () {
      BtrBangumiApi.setBaseUrl('   ');

      expect(
        BtrBangumiApi.baseUrl,
        BTAppConstants.bangumiApiBaseUrl,
      );
    });
  });

  group('handleBangumiDioException', () {
    test('handles a handshake failure without response data', () {
      var exception = DioException(
        requestOptions: RequestOptions(
          path: '/v0/me',
          baseUrl: 'https://api.bangumi.one',
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
}
