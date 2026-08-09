import 'dart:async';

import 'package:bangumi_today/core/services/app_link_service.dart';
import 'package:bangumi_today/core/services/bangumi_oauth_coordinator.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/request/bangumi/bangumi_oauth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BangumiOAuthCoordinator', () {
    late _FakeAppLinkSource source;
    late AppLinkService appLinkService;

    setUp(() {
      source = _FakeAppLinkSource();
      appLinkService = AppLinkService.forTesting(source);
    });

    tearDown(() async {
      await appLinkService.dispose();
    });

    BangumiOAuthCoordinator buildCoordinator({
      String state = 'fixed-state',
      Duration timeout = const Duration(minutes: 5),
    }) {
      return BangumiOAuthCoordinator.forTesting(
        appLinkService: appLinkService,
        stateGenerator: () => state,
        callbackTimeout: timeout,
      );
    }

    Uri oauthCallback({
      String code = 'auth-code',
      String state = 'fixed-state',
    }) {
      return Uri.parse('bangumitoday://oauth?code=$code&state=$state');
    }

    test('exchanges the token once for a valid callback', () async {
      var gateway = _FakeOauthGateway(source, callback: oauthCallback());

      var result = await buildCoordinator().authorize(gateway);

      expect(result.code, 0);
      expect(gateway.authorizeStates, ['fixed-state']);
      expect(gateway.tokenCalls, hasLength(1));
      expect(gateway.tokenCalls.single.code, 'auth-code');
      expect(gateway.tokenCalls.single.state, 'fixed-state');
    });

    test('rejects a callback with a missing code', () async {
      var gateway = _FakeOauthGateway(
        source,
        callback: Uri.parse('bangumitoday://oauth?state=fixed-state'),
      );

      var result = await buildCoordinator().authorize(gateway);

      expect(result.code, 400);
      expect(result.message, contains('授权码'));
      expect(gateway.tokenCalls, isEmpty);
    });

    test('rejects a callback with a wrong state', () async {
      var gateway = _FakeOauthGateway(
        source,
        callback: oauthCallback(state: 'wrong-state'),
      );

      var result = await buildCoordinator().authorize(gateway);

      expect(result.code, 400);
      expect(result.message, contains('校验失败'));
      expect(gateway.tokenCalls, isEmpty);
    });

    test(
      'ignores duplicate callbacks and exchanges the token only once',
      () async {
        var gateway = _FakeOauthGateway(
          source,
          callbacks: [
            oauthCallback(code: 'first-code'),
            oauthCallback(code: 'second-code'),
          ],
        );

        var result = await buildCoordinator().authorize(gateway);

        expect(result.code, 0);
        expect(gateway.tokenCalls, hasLength(1));
        expect(gateway.tokenCalls.single.code, 'first-code');
      },
    );

    test('times out while waiting for the callback', () async {
      var gateway = _FakeOauthGateway(source);

      var result = await buildCoordinator(
        timeout: const Duration(milliseconds: 50),
      ).authorize(gateway);

      expect(result.code, 408);
      expect(result.message, contains('超时'));
      expect(gateway.tokenCalls, isEmpty);
    });

    test('ignores a late callback after timeout and stays usable', () async {
      var gateway = _FakeOauthGateway(source);
      var coordinator = buildCoordinator(
        timeout: const Duration(milliseconds: 50),
      );

      var result = await coordinator.authorize(gateway);
      expect(result.code, 408);

      source.add(oauthCallback(code: 'too-late'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(gateway.tokenCalls, isEmpty);

      var secondGateway = _FakeOauthGateway(
        source,
        callback: oauthCallback(code: 'second-code'),
      );
      var second = await coordinator.authorize(secondGateway);
      expect(second.code, 0);
      expect(secondGateway.tokenCalls.single.code, 'second-code');
    });

    test('rejects a second authorize while one is in flight', () async {
      var firstGateway = _FakeOauthGateway(
        source,
        delayAuthorize: true,
        callback: oauthCallback(code: 'first-code'),
      );
      var coordinator = buildCoordinator();

      var first = coordinator.authorize(firstGateway);
      var second = await coordinator.authorize(_FakeOauthGateway(source));

      expect(second.code, 409);
      expect(firstGateway.authorizeStates, hasLength(1));

      firstGateway.completeAuthorize();
      var firstResult = await first;
      expect(firstResult.code, 0);
      expect(firstGateway.tokenCalls.single.code, 'first-code');
    });

    test(
      'cold start OAuth callback exchanges the token exactly once',
      () async {
        source.initialLink = oauthCallback();
        var gateway = _FakeOauthGateway(source);

        var result = await buildCoordinator().authorize(gateway);

        expect(result.code, 0);
        expect(gateway.authorizeStates, ['fixed-state']);
        expect(gateway.tokenCalls, hasLength(1));
        expect(gateway.tokenCalls.single.state, 'fixed-state');
      },
    );
  });
}

class _FakeAppLinkSource implements AppLinkSource {
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();
  Uri? initialLink;

  void add(Uri uri) => _controller.add(uri);

  @override
  Stream<Uri> get uriLinkStream => _controller.stream;

  @override
  Future<Uri?> getInitialLink() async => initialLink;
}

class _FakeOauthGateway implements BangumiOauthGateway {
  _FakeOauthGateway(
    this._source, {
    this.callback,
    this.callbacks = const [],
    this.delayAuthorize = false,
  });

  final _FakeAppLinkSource _source;
  final Uri? callback;
  final List<Uri> callbacks;
  final bool delayAuthorize;

  final List<String?> authorizeStates = [];
  final List<({String code, String? state})> tokenCalls = [];
  final Completer<void> _authorizeGate = Completer<void>();
  BTResponse tokenResponse = BTResponse.success(data: 'ok');

  @override
  Future<void> openAuthorizePage({String? state}) async {
    authorizeStates.add(state);
    if (delayAuthorize) {
      await _authorizeGate.future;
    }
    if (callback != null) _source.add(callback!);
    for (var uri in callbacks) {
      _source.add(uri);
    }
  }

  void completeAuthorize() {
    if (!_authorizeGate.isCompleted) _authorizeGate.complete();
  }

  @override
  Future<BTResponse> getAccessToken(String code, {String? state}) async {
    tokenCalls.add((code: code, state: state));
    return tokenResponse;
  }
}
