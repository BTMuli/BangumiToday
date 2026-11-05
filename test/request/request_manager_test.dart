// Dart imports:
import 'dart:async';

// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/request/bangumi/bangumi_manager.dart';

Future<void> _holdUntilCancelled(CancelToken token) async {
  while (!token.isCancelled) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw DioException(
    requestOptions: RequestOptions(path: '/'),
    type: DioExceptionType.cancel,
  );
}

void main() {
  late RequestManager manager;

  setUp(() {
    manager = RequestManager();
    manager.cancelAll();
  });

  tearDown(() => manager.cancelAll());

  test('相同 key 在进行中时去重复用同一 Future', () async {
    var started = 0;
    Future<int> run() => manager.request(
      key: 'dup',
      request: (token) async {
        started++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(token.isCancelled, isFalse);
        return 7;
      },
    );

    var results = await Future.wait([run(), run()]);
    expect(results, [7, 7]);
    expect(started, 1);
    expect(manager.isPending('dup'), isFalse);
  });

  test('cancelPrevious 会取消旧请求并启动新请求', () async {
    var firstToken = Completer<CancelToken>();
    var first = manager.request(
      key: 'replace',
      request: (token) async {
        firstToken.complete(token);
        await _holdUntilCancelled(token);
        return 1;
      },
    );
    var token = await firstToken.future;
    var second = manager.request(
      key: 'replace',
      cancelPrevious: true,
      request: (token) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 2;
      },
    );
    await expectLater(first, throwsA(isA<DioException>()));
    expect(token.isCancelled, isTrue);
    expect(await second, 2);
  });

  test('完成后清除 pending 与去重缓存', () async {
    await manager.request(key: 'done', request: (_) async => 'ok');
    expect(manager.isPending('done'), isFalse);
    expect(manager.pendingKeys, isEmpty);

    var started = 0;
    await manager.request(
      key: 'done',
      request: (_) async {
        started++;
        return 'again';
      },
    );
    expect(started, 1);
  });

  test('cancel 与 cancelAll 清理状态', () async {
    var tokenReady = Completer<CancelToken>();
    var pending = manager.request(
      key: 'a',
      request: (token) async {
        tokenReady.complete(token);
        await _holdUntilCancelled(token);
        return 1;
      },
    );
    await tokenReady.future;
    expect(manager.cancel('a'), isTrue);
    await expectLater(pending, throwsA(isA<DioException>()));
    expect(manager.isPending('a'), isFalse);

    var bReady = Completer<CancelToken>();
    var cReady = Completer<CancelToken>();
    var b = manager.request(
      key: 'b',
      request: (token) async {
        bReady.complete(token);
        await _holdUntilCancelled(token);
        return 1;
      },
    );
    var c = manager.request(
      key: 'c',
      request: (token) async {
        cReady.complete(token);
        await _holdUntilCancelled(token);
        return 1;
      },
    );
    await Future.wait([bReady.future, cReady.future]);
    manager.cancelAll();
    await expectLater(b, throwsA(isA<DioException>()));
    await expectLater(c, throwsA(isA<DioException>()));
    expect(manager.pendingKeys, isEmpty);
  });

  test('withRetry 对取消异常直接抛出且不重试', () async {
    var attempts = 0;
    await expectLater(
      manager.withRetry(
        maxRetries: 3,
        delay: Duration.zero,
        request: () async {
          attempts++;
          throw DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.cancel,
          );
        },
      ),
      throwsA(isA<DioException>()),
    );
    expect(attempts, 1);
  });

  test('withRetry 对可重试错误按次数重试后成功', () async {
    var attempts = 0;
    var value = await manager.withRetry(
      maxRetries: 3,
      delay: Duration.zero,
      request: () async {
        attempts++;
        if (attempts < 3) {
          throw DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionTimeout,
          );
        }
        return 'ok';
      },
    );
    expect(value, 'ok');
    expect(attempts, 3);
  });
}
