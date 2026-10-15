// Dart imports:
import 'dart:async';

// Project imports:
import '../../tools/log_tool.dart';

/// Serializes accepted playback work and keeps timed-out cleanup alive.
/// Native destruction settles separately from the work needed to hide a window.
class PlaybackSessionLifecycle {
  PlaybackSessionLifecycle({required this.onOperationError});

  final void Function(Object, StackTrace) onOperationError;
  Future<void> _operation = Future.value();
  Future<void>? _shutdownFuture;
  Future<void>? _workFuture;
  Future<void>? _settlementFuture;
  final _shutdownWork = <Future<void>>[];
  final _nativeDestructions = <Future<void>>[];
  final _failures = <Object>[];
  bool _closed = false;

  bool get isClosed => _closed;
  Future<void> get pending => _operation;

  Future<void> run(Future<void> Function() action) {
    var next = _operation.then((_) async {
      if (_closed) return;
      await action();
    });
    _operation = next.catchError(onOperationError);
    return next;
  }

  Future<void> shutdown(Future<void> Function() action) =>
      _shutdownFuture ??= _beginShutdown(action);

  Future<void> _beginShutdown(Future<void> Function() action) {
    _closed = true;
    return Future<void>.sync(action);
  }

  Future<void> waitForWork(Future<void> Function() shutdown) =>
      _workFuture ??= _waitForWork(shutdown);

  Future<void> _waitForWork(Future<void> Function() shutdown) async {
    await shutdown();
    await Future.wait(_shutdownWork);
    _checkFailures();
  }

  Future<void> waitForSettlement(Future<void> Function() shutdown) =>
      _settlementFuture ??= _waitForSettlement(shutdown);

  Future<void> _waitForSettlement(Future<void> Function() shutdown) async {
    await waitForWork(shutdown);
    await Future.wait(_nativeDestructions);
    _checkFailures();
  }

  void recordFailure(Object error) => _failures.add(error);

  void _checkFailures() {
    if (_failures.isNotEmpty) {
      throw StateError('播放器未能完成保存或清理：${_failures.first}');
    }
  }

  void trackCleanup(Future<void> work) {
    _shutdownWork.add(work.catchError(recordFailure));
  }

  void trackNativeDisposal(
    Future<void> disposal, {
    required bool waitForNativeDestroy,
  }) {
    // media_kit schedules mpv_terminate_destroy after Player.dispose returns.
    var destruction = disposal
        .then((_) async {
          if (waitForNativeDestroy) {
            await Future<void>.delayed(const Duration(milliseconds: 5200));
          }
        })
        .catchError(recordFailure);
    _nativeDestructions.add(destruction);
  }

  Future<bool> step(
    String name,
    Future<void> Function() action,
    Duration timeout,
  ) async {
    var work = Future<void>.sync(action);
    trackCleanup(work);
    try {
      await work.timeout(timeout);
      return true;
    } on TimeoutException {
      BTLogTool.warn('播放器清理超时：$name');
    } catch (error, stackTrace) {
      BTLogTool.error(['播放器清理失败：$name，$error', stackTrace.toString()]);
    }
    return false;
  }
}
