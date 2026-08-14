// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/bangumi_token_service.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/bangumi/bangumi_oauth_model.dart';

void main() {
  late DateTime now;
  late String? storedAccessToken;
  late String? storedRefreshToken;
  late DateTime? storedExpireTime;
  late int refreshCalls;

  BangumiOauthTokenRefreshData refreshedData({
    String access = 'new-access',
    String refresh = 'new-refresh',
    int expiresIn = 3600,
  }) {
    return BangumiOauthTokenRefreshData(
      accessToken: access,
      expiresIn: expiresIn,
      tokenType: 'Bearer',
      scope: null,
      refreshToken: refresh,
    );
  }

  setUp(() {
    now = DateTime(2026, 8, 14, 12);
    storedAccessToken = 'old-access';
    storedRefreshToken = 'old-refresh';
    storedExpireTime = now.add(const Duration(days: 3));
    refreshCalls = 0;
  });

  BangumiTokenService buildService({
    BangumiTokenRefresher? refresh,
    Duration refreshAhead = BangumiTokenService.defaultRefreshAhead,
  }) {
    return BangumiTokenService.forTesting(
      readAccessToken: () => storedAccessToken,
      readRefreshToken: () => storedRefreshToken,
      readExpireTime: () => storedExpireTime,
      refreshToken:
          refresh ??
          (_) async {
            refreshCalls++;
            storedAccessToken = 'new-access';
            storedRefreshToken = 'new-refresh';
            storedExpireTime = now.add(const Duration(days: 3));
            return BangumiOauthTokenRefreshResp.success(data: refreshedData());
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
      refreshAhead: refreshAhead,
    );
  }

  test('does not refresh before the refresh window', () async {
    var service = buildService();

    var result = await service.ensureFresh();

    expect(result, BangumiTokenRefreshResult.notNeeded);
    expect(refreshCalls, 0);
    expect(await service.accessTokenForRequest(), 'old-access');
  });

  test('refreshes inside and exactly at the refresh boundary', () async {
    var service = buildService();

    storedExpireTime = now.add(const Duration(hours: 23));
    expect(await service.ensureFresh(), BangumiTokenRefreshResult.refreshed);
    expect(refreshCalls, 1);

    refreshCalls = 0;
    storedExpireTime = now.add(const Duration(days: 1));
    storedAccessToken = 'old-access';
    storedRefreshToken = 'old-refresh';
    service = buildService();
    expect(await service.ensureFresh(), BangumiTokenRefreshResult.refreshed);
    expect(refreshCalls, 1);
  });

  test('reports unavailable when refresh token is missing', () async {
    storedRefreshToken = null;
    var service = buildService();

    expect(
      await service.ensureFresh(force: true),
      BangumiTokenRefreshResult.unavailable,
    );
    expect(refreshCalls, 0);
  });

  test('shares one refresh request between concurrent callers', () async {
    var refreshCompleter = Completer<BTResponse>();
    var service = buildService(
      refresh: (_) {
        refreshCalls++;
        return refreshCompleter.future;
      },
    );

    var first = service.ensureFresh(force: true);
    var second = service.ensureFresh(force: true);
    await Future<void>.delayed(Duration.zero);

    expect(refreshCalls, 1);
    refreshCompleter.complete(
      BangumiOauthTokenRefreshResp.success(data: refreshedData()),
    );
    var results = await Future.wait([first, second]);

    expect(results, [
      BangumiTokenRefreshResult.refreshed,
      BangumiTokenRefreshResult.refreshed,
    ]);
    expect(storedAccessToken, 'new-access');
  });

  test('does not switch tokens when refresh response is invalid', () async {
    var service = buildService(
      refresh: (_) async {
        refreshCalls++;
        return BTResponse.error(code: 400, message: 'invalid', data: null);
      },
    );

    expect(
      await service.ensureFresh(force: true),
      BangumiTokenRefreshResult.failed,
    );
    expect(refreshCalls, 1);
    expect(storedAccessToken, 'old-access');
    expect(storedRefreshToken, 'old-refresh');
  });
}
