// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/utils/async_pool.dart';

void main() {
  test('single flight reuses an in-flight operation and resets', () async {
    var guard = AsyncSingleFlight();
    var release = Completer<void>();
    var calls = 0;

    Future<void> action() async {
      calls++;
      await release.future;
    }

    var first = guard.run(action);
    var second = guard.run(action);

    expect(identical(first, second), isTrue);
    expect(guard.isRunning, isTrue);
    expect(calls, 1);

    release.complete();
    await Future.wait([first, second]);

    expect(guard.isRunning, isFalse);
    await guard.run(() async => calls++);
    expect(calls, 2);
  });

  test('single flight resets after an error', () async {
    var guard = AsyncSingleFlight();

    await expectLater(
      guard.run(() async => throw StateError('failed')),
      throwsStateError,
    );

    expect(guard.isRunning, isFalse);
    await guard.run(() async {});
  });

  test('serializes operations sharing the same key', () async {
    var executor = KeyedAsyncSerialExecutor<String>();
    var firstRelease = Completer<void>();
    var events = <String>[];

    var first = executor.run('rss', () async {
      events.add('first-start');
      await firstRelease.future;
      events.add('first-end');
      return 1;
    });
    var second = executor.run('rss', () async {
      events.add('second-start');
      return 2;
    });

    await Future<void>.delayed(Duration.zero);
    expect(events, ['first-start']);

    firstRelease.complete();
    expect(await first, 1);
    expect(await second, 2);
    expect(events, ['first-start', 'first-end', 'second-start']);
  });

  test('a failed keyed operation does not block the next one', () async {
    var executor = KeyedAsyncSerialExecutor<String>();

    var failed = executor.run<void>(
      'rss',
      () async => throw StateError('failed'),
    );
    var recovered = executor.run('rss', () async => 2);

    await expectLater(failed, throwsStateError);
    expect(await recovered, 2);
  });

  test('limits the number of concurrent operations', () async {
    var active = 0;
    var maxActive = 0;
    var processed = <int>[];

    await forEachConcurrent(
      List.generate(12, (index) => index),
      maxConcurrent: 3,
      action: (item) async {
        active++;
        if (active > maxActive) maxActive = active;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        processed.add(item);
        active--;
      },
    );

    expect(maxActive, 3);
    expect(processed, hasLength(12));
    expect(
      processed.toSet(),
      Set<int>.from(List.generate(12, (index) => index)),
    );
  });

  test('does not start more workers than items', () async {
    var active = 0;
    var maxActive = 0;
    var release = Completer<void>();

    var operation = forEachConcurrent(
      [1, 2],
      maxConcurrent: 5,
      action: (_) async {
        active++;
        if (active > maxActive) maxActive = active;
        await release.future;
        active--;
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(maxActive, 2);
    release.complete();
    await operation;
  });

  test('rejects a non-positive concurrency limit', () {
    expect(
      () => forEachConcurrent<int>(
        const [],
        maxConcurrent: 0,
        action: (_) async {},
      ),
      throwsArgumentError,
    );
  });
}
