import 'dart:async';

import 'package:bangumi_today/core/services/app_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLinkService', () {
    test(
      'exposes a single shared subscription for repeated stream access',
      () async {
        var source = _FakeAppLinkSource();
        var service = AppLinkService.forTesting(source);

        var streamA = service.stream;
        var streamB = service.stream;
        var received = <Uri>[];
        var subscriptionA = streamA.listen(received.add);
        var subscriptionB = streamB.listen(received.add);
        var uri = Uri.parse('bangumitoday://subject/9');
        source.add(uri);
        await Future<void>.delayed(Duration.zero);

        // 两个页面级监听者共享同一条原生订阅，事件都会送达。
        expect(received, [uri, uri]);
        expect(source.nativeListenCount, 1);

        await subscriptionA.cancel();
        await subscriptionB.cancel();
        await service.dispose();
      },
    );

    test('emits the initial link once at startup', () async {
      var initialLink = Uri.parse('bangumitoday://subject/1');
      var source = _FakeAppLinkSource(initialLink: initialLink);
      var service = AppLinkService.forTesting(source);
      var received = <Uri>[];

      var subscription = service.stream.listen(received.add);
      await Future<void>.delayed(Duration.zero);

      expect(received, [initialLink]);
      await subscription.cancel();
      await service.dispose();
    });

    test(
      'dispose cancels the native subscription and restart resubscribes',
      () async {
        var initialLink = Uri.parse('bangumitoday://subject/2');
        var source = _FakeAppLinkSource(initialLink: initialLink);
        var service = AppLinkService.forTesting(source);
        var first = <Uri>[];
        var firstSubscription = service.stream.listen(first.add);
        await Future<void>.delayed(Duration.zero);
        expect(first, [initialLink]);

        await service.dispose();
        expect(source.nativeListenCount, 0);

        var second = <Uri>[];
        var secondSubscription = service.stream.listen(second.add);
        await Future<void>.delayed(Duration.zero);

        expect(source.nativeListenCount, 1);
        expect(second, [initialLink]);
        await firstSubscription.cancel();
        await secondSubscription.cancel();
        await service.dispose();
      },
    );

    test('swallows native stream errors and keeps delivering links', () async {
      var source = _FakeAppLinkSource();
      var service = AppLinkService.forTesting(source);
      var received = <Uri>[];
      var errors = <Object>[];

      var subscription = service.stream.listen(
        received.add,
        onError: errors.add,
      );
      source.addError(Exception('native link error'));
      source.add(Uri.parse('bangumitoday://subject/3'));
      await Future<void>.delayed(Duration.zero);

      expect(errors, isEmpty);
      expect(received, [Uri.parse('bangumitoday://subject/3')]);
      await subscription.cancel();
      await service.dispose();
    });

    test(
      'swallows initial link failures as a normal startup condition',
      () async {
        var source = _FakeAppLinkSource(throwOnInitialLink: true);
        var service = AppLinkService.forTesting(source);
        var received = <Uri>[];

        var subscription = service.stream.listen(received.add);
        await Future<void>.delayed(Duration.zero);

        expect(received, isEmpty);
        await subscription.cancel();
        await service.dispose();
      },
    );
  });
}

class _FakeAppLinkSource implements AppLinkSource {
  _FakeAppLinkSource({this.initialLink, this.throwOnInitialLink = false}) {
    _controller = StreamController<Uri>.broadcast(
      onListen: () => _nativeListenCount++,
      onCancel: () => _nativeListenCount--,
    );
  }

  final Uri? initialLink;
  final bool throwOnInitialLink;

  late final StreamController<Uri> _controller;

  int _nativeListenCount = 0;

  int get nativeListenCount => _nativeListenCount;

  void add(Uri uri) => _controller.add(uri);

  void addError(Object error) => _controller.addError(error);

  @override
  Stream<Uri> get uriLinkStream => _controller.stream;

  @override
  Future<Uri?> getInitialLink() async {
    if (throwOnInitialLink) throw StateError('initial link unavailable');
    return initialLink;
  }
}
