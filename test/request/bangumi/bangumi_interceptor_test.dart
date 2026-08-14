// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/bangumi_token_service.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/bangumi/bangumi_oauth_model.dart';
import 'package:bangumi_today/request/core/client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late String? storedAccessToken;
  late String? storedRefreshToken;
  late DateTime? storedExpireTime;
  late int refreshCalls;

  setUp(() {
    now = DateTime(2026, 8, 14, 12);
    storedAccessToken = 'old-access';
    storedRefreshToken = 'old-refresh';
    storedExpireTime = now.add(const Duration(days: 2));
    refreshCalls = 0;
  });

  BangumiOauthTokenRefreshData refreshData() {
    return BangumiOauthTokenRefreshData(
      accessToken: 'new-access',
      expiresIn: 3600,
      tokenType: 'Bearer',
      scope: null,
      refreshToken: 'new-refresh',
    );
  }

  BangumiTokenService buildService({BangumiTokenRefresher? refresh}) {
    return BangumiTokenService.forTesting(
      readAccessToken: () => storedAccessToken,
      readRefreshToken: () => storedRefreshToken,
      readExpireTime: () => storedExpireTime,
      refreshToken:
          refresh ??
          (_) async {
            refreshCalls++;
            return BangumiOauthTokenRefreshResp.success(data: refreshData());
          },
      writeTokenSet:
          ({
            required String accessToken,
            required String refreshToken,
            required int expiresIn,
          }) async {
            storedAccessToken = accessToken;
            storedRefreshToken = refreshToken;
            storedExpireTime = now.add(Duration(seconds: expiresIn));
          },
      now: () => now,
    );
  }

  Future<Response<dynamic>> getResource(
    BangumiTokenService tokenService,
    _AuthHttpAdapter adapter,
  ) async {
    var client = BtrClient.withAuth(tokenService: tokenService);
    client.dio.options.baseUrl = 'https://example.test';
    client.dio.httpClientAdapter = adapter;
    return client.dio.get('/resource');
  }

  test('refreshes after a real 401 and retries with the new token', () async {
    var service = buildService(
      refresh: (_) async {
        refreshCalls++;
        storedAccessToken = 'new-access';
        storedRefreshToken = 'new-refresh';
        storedExpireTime = now.add(const Duration(days: 2));
        return BangumiOauthTokenRefreshResp.success(data: refreshData());
      },
    );
    var adapter = _AuthHttpAdapter();

    var response = await getResource(service, adapter);

    expect(response.statusCode, HttpStatus.ok);
    expect(refreshCalls, 1);
    expect(adapter.authorizationHeaders, [
      'Bearer old-access',
      'Bearer new-access',
    ]);
  });

  test('does not retry when refresh fails', () async {
    var service = buildService(
      refresh: (_) async {
        refreshCalls++;
        return BTResponse.error(code: 400, message: 'invalid', data: null);
      },
    );
    var adapter = _AuthHttpAdapter(alwaysUnauthorized: true);

    await expectLater(
      getResource(service, adapter),
      throwsA(isA<DioException>()),
    );

    expect(refreshCalls, 1);
    expect(adapter.authorizationHeaders, ['Bearer old-access']);
  });

  test(
    'does not loop when the retried request is still unauthorized',
    () async {
      var service = buildService(
        refresh: (_) async {
          refreshCalls++;
          storedAccessToken = 'new-access';
          storedRefreshToken = 'new-refresh';
          storedExpireTime = now.add(const Duration(days: 2));
          return BangumiOauthTokenRefreshResp.success(data: refreshData());
        },
      );
      var adapter = _AuthHttpAdapter(alwaysUnauthorized: true);

      await expectLater(
        getResource(service, adapter),
        throwsA(isA<DioException>()),
      );

      expect(refreshCalls, 1);
      expect(adapter.authorizationHeaders, [
        'Bearer old-access',
        'Bearer new-access',
      ]);
    },
  );

  test('shares one refresh between multiple authenticated clients', () async {
    var refreshCompleter = Completer<BTResponse>();
    var service = buildService(
      refresh: (_) {
        refreshCalls++;
        return refreshCompleter.future;
      },
    );
    var adapter = _AuthHttpAdapter();
    var first = getResource(service, adapter);
    var second = getResource(service, adapter);
    await adapter.initialRequestsReady.future;
    for (var i = 0; i < 10 && refreshCalls == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(refreshCalls, 1);
    storedAccessToken = 'new-access';
    storedRefreshToken = 'new-refresh';
    storedExpireTime = now.add(const Duration(days: 2));
    refreshCompleter.complete(
      BangumiOauthTokenRefreshResp.success(data: refreshData()),
    );

    var responses = await Future.wait([first, second]);

    expect(responses.map((response) => response.statusCode), [200, 200]);
    expect(refreshCalls, 1);
    expect(
      adapter.authorizationHeaders.where(
        (header) => header == 'Bearer new-access',
      ),
      hasLength(2),
    );
  });
}

class _AuthHttpAdapter implements HttpClientAdapter {
  _AuthHttpAdapter({this.alwaysUnauthorized = false});

  final bool alwaysUnauthorized;
  final List<String?> authorizationHeaders = [];
  final Completer<void> initialRequestsReady = Completer<void>();
  var _oldTokenRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    var authorization = options.headers['Authorization']?.toString();
    authorizationHeaders.add(authorization);
    var isAuthorized = authorization == 'Bearer new-access';
    if (!isAuthorized) {
      _oldTokenRequests++;
      if (_oldTokenRequests >= 2 && !initialRequestsReady.isCompleted) {
        initialRequestsReady.complete();
      }
    }
    if (alwaysUnauthorized || !isAuthorized) {
      return ResponseBody.fromString(
        jsonEncode({'description': 'Unauthorized'}),
        HttpStatus.unauthorized,
        headers: {
          HttpHeaders.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      HttpStatus.ok,
      headers: {
        HttpHeaders.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
