// Dart imports:
import 'dart:async';
import 'dart:math' as math;

/// Deduplicates concurrent calls while an asynchronous operation is running.
class AsyncSingleFlight {
  Future<void>? _inFlight;

  bool get isRunning => _inFlight != null;

  Future<void> run(Future<void> Function() action) {
    var current = _inFlight;
    if (current != null) return current;

    late Future<void> operation;
    operation = Future<void>.sync(action).whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
    _inFlight = operation;
    return operation;
  }
}

/// Runs operations for the same key sequentially.
///
/// Operations using different keys can still run concurrently.
class KeyedAsyncSerialExecutor<K> {
  final Map<K, Future<void>> _tails = {};

  Future<T> run<T>(K key, Future<T> Function() action) {
    var result = Completer<T>();
    var previous = _tails[key] ?? Future<void>.value();

    late Future<void> tail;
    tail = previous.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    _tails[key] = tail;

    unawaited(
      tail.whenComplete(() {
        if (identical(_tails[key], tail)) {
          unawaited(_tails.remove(key));
        }
      }),
    );
    return result.future;
  }
}

/// Processes [items] with at most [maxConcurrent] asynchronous operations.
///
/// Items are claimed synchronously before each operation starts, so every item
/// is processed at most once while avoiding an eagerly-created future per item.
Future<void> forEachConcurrent<T>(
  Iterable<T> items, {
  required int maxConcurrent,
  required Future<void> Function(T item) action,
}) async {
  if (maxConcurrent < 1) {
    throw ArgumentError.value(
      maxConcurrent,
      'maxConcurrent',
      'Must be greater than zero',
    );
  }

  var pending = items.toList(growable: false);
  if (pending.isEmpty) return;

  var nextIndex = 0;

  Future<void> worker() async {
    while (nextIndex < pending.length) {
      var item = pending[nextIndex];
      nextIndex++;
      await action(item);
    }
  }

  await Future.wait(
    List.generate(math.min(maxConcurrent, pending.length), (_) => worker()),
  );
}
