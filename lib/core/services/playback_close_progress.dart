// Dart imports:
import 'dart:async';

/// Reports slow cleanup without abandoning work that still owns native state.
class PlaybackCloseProgress {
  const PlaybackCloseProgress({
    this.onChanged,
    this.onLog,
    this.slowAfter = const Duration(seconds: 5),
  });

  final void Function(String stage, bool slow)? onChanged;
  final void Function(String message)? onLog;
  final Duration slowAfter;

  Future<T> run<T>(String stage, Future<T> Function() action) async {
    var elapsed = Stopwatch()..start();
    onChanged?.call(stage, false);
    onLog?.call('$stage：开始');
    var timer = Timer(slowAfter, () {
      onChanged?.call(stage, true);
      onLog?.call('$stage：仍在等待，耗时 ${elapsed.elapsedMilliseconds}ms');
    });
    try {
      var result = await action();
      onLog?.call('$stage：完成，耗时 ${elapsed.elapsedMilliseconds}ms');
      return result;
    } catch (error) {
      onLog?.call('$stage：失败，耗时 ${elapsed.elapsedMilliseconds}ms，$error');
      rethrow;
    } finally {
      timer.cancel();
      elapsed.stop();
    }
  }
}
