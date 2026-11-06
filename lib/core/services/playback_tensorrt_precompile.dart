// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

// Package imports:
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../utils/playback_build_log.dart';

typedef PlaybackTensorRtTarget = ({
  int slot,
  int width,
  int height,
  String renderer,
});

class PlaybackTensorRtPreparation {
  PlaybackTensorRtPreparation(Map<String, dynamic> event)
    : phase = event['phase'] as String,
      completed = event['completed'] as int,
      total = event['total'] as int,
      task = event['task'] as String,
      reason = event['reason'] as String,
      buildRequired = event['buildRequired'] as bool,
      lines = List<String>.unmodifiable(
        (event['lines'] as List? ?? const []).cast<String>(),
      );

  final String phase;
  final int completed;
  final int total;
  final String task;
  final String reason;
  final bool buildRequired;
  final List<String> lines;
  String get label => task.isEmpty
      ? reason
      : '${math.min(completed + 1, total)} / $total · $task · $reason';
}

/// The native shim shares playback's cache and builder. Polling, log reads and
/// cancellation/join live in an isolate, without a Player or a video frame.
class PlaybackTensorRtPrecompile {
  // The main and playback engines each own the jobs started in their isolate.
  static final _active = <PlaybackTensorRtPrecompile>{};
  static bool _stoppingForExit = false;

  static bool get isRunning => _active.isNotEmpty;

  static Future<void> stopForExit() async {
    _stoppingForExit = true;
    for (var job in _active) {
      job.cancel();
    }
    await Future.wait([for (var job in _active) job._settled!.future]);
  }

  static void resumeAfterCancelledExit() => _stoppingForExit = false;

  /// CUDA retirement and file-lease release must stay off the UI isolate.
  static Future<void> clearPreparedCache() async {
    if (!Platform.isWindows) return;
    var bundle = path.dirname(Platform.resolvedExecutable);
    await Isolate.run(() {
      DynamicLibrary.open(
        path.join(bundle, 'aji.dll'),
      ).lookupFunction<Void Function(), void Function()>(
        'bt_trt_precompile_clear_cache',
      )();
    });
  }

  SendPort? _control;
  bool _cancelled = false;
  Completer<void>? _settled;

  void cancel() {
    _cancelled = true;
    _control?.send('cancel');
  }

  Future<void> run({
    required String bundle,
    required String runtime,
    required String cache,
    required int sm,
    PlaybackTensorRtTarget? target,
    required void Function(PlaybackTensorRtPreparation) onProgress,
  }) async {
    if (_stoppingForExit) throw StateError('应用正在退出');
    if (_settled != null) throw StateError('TensorRT 预编译已在运行');
    var settled = Completer<void>();
    _settled = settled;
    _active.add(this);
    _cancelled = false;
    var events = ReceivePort();
    try {
      await Isolate.spawn(
        _prepare,
        [events.sendPort, bundle, runtime, cache, sm, ?target],
        onError: events.sendPort,
        onExit: events.sendPort,
      );
      PlaybackTensorRtPreparation? result;
      AsyncError? failure;
      await for (var event in events) {
        if (event is SendPort) {
          _control = event;
          if (_cancelled) event.send('cancel');
        } else if (event == null) {
          break;
        } else if (failure == null) {
          try {
            if (event is Map) {
              result = PlaybackTensorRtPreparation(
                Map<String, dynamic>.from(event),
              );
              onProgress(result);
            } else if (event is List) {
              throw StateError('引擎准备任务异常：${event.first}');
            }
          } catch (error, stackTrace) {
            // Keep waiting for native cleanup if progress reporting fails.
            failure = AsyncError(error, stackTrace);
            cancel();
          }
        }
      }
      if (failure != null) {
        Error.throwWithStackTrace(failure.error, failure.stackTrace);
      }
      if (result?.phase != 'ready') {
        throw StateError(result?.reason ?? '引擎准备任务意外退出');
      }
    } finally {
      _control?.send('cancel');
      _control = null;
      events.close();
      _active.remove(this);
      _settled = null;
      settled.complete();
    }
  }

  static Future<void> _prepare(List<Object> request) async {
    var events = request[0] as SendPort;
    var bundle = request[1] as String;
    var runtime = request[2] as String;
    var cache = request[3] as String;
    var sm = request[4] as int;
    var target = request.length > 5
        ? request[5] as PlaybackTensorRtTarget
        : null;
    var commands = ReceivePort();
    var cancelled = false;
    var subscription = commands.listen((_) => cancelled = true);
    events.send(commands.sendPort);
    Pointer<Void> job = nullptr;
    void Function(Pointer<Void>)? close;
    var status = <String, dynamic>{
      'phase': 'preparing',
      'completed': 0,
      'total': target == null ? 4 : 1,
      'task': '',
      'reason': '正在启动引擎准备任务',
      'buildRequired': false,
    };
    try {
      var library = DynamicLibrary.open(path.join(bundle, 'aji.dll'));
      var start = library
          .lookupFunction<
            Pointer<Void> Function(
              Pointer<Utf16>,
              Pointer<Utf16>,
              Pointer<Utf16>,
              Int32,
            ),
            Pointer<Void> Function(
              Pointer<Utf16>,
              Pointer<Utf16>,
              Pointer<Utf16>,
              int,
            )
          >('bt_trt_precompile_start');
      var poll = library
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Void>),
            Pointer<Utf8> Function(Pointer<Void>)
          >('bt_trt_precompile_poll');
      var cancel = library
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('bt_trt_precompile_cancel');
      close = library
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('bt_trt_precompile_close');
      job = using((arena) {
        var bundlePath = bundle.toNativeUtf16(allocator: arena);
        var runtimePath = runtime.toNativeUtf16(allocator: arena);
        var cachePath = cache.toNativeUtf16(allocator: arena);
        if (target == null) {
          return start(bundlePath, runtimePath, cachePath, sm);
        }
        var startTarget = library
            .lookupFunction<
              Pointer<Void> Function(
                Pointer<Utf16>,
                Pointer<Utf16>,
                Pointer<Utf16>,
                Int32,
                Int32,
                Int32,
                Int32,
                Pointer<Utf16>,
              ),
              Pointer<Void> Function(
                Pointer<Utf16>,
                Pointer<Utf16>,
                Pointer<Utf16>,
                int,
                int,
                int,
                int,
                Pointer<Utf16>,
              )
            >('bt_trt_precompile_target_start');
        return startTarget(
          bundlePath,
          runtimePath,
          cachePath,
          sm,
          target.slot,
          target.width,
          target.height,
          target.renderer.toNativeUtf16(allocator: arena),
        );
      });
      if (job == nullptr) throw StateError('无法启动 TensorRT 引擎准备');
      var previousLog = '';
      List<String> lines = const [];
      while (true) {
        if (cancelled) cancel(job);
        var json = poll(job);
        if (json == nullptr) throw StateError('无法读取 TensorRT 编译状态');
        status = jsonDecode(json.toDartString()) as Map<String, dynamic>;
        var log = status['log'] as String;
        if (previousLog != log) lines = const [];
        previousLog = log;
        if (log.isNotEmpty &&
            path.isWithin(cache, path.normalize(log)) &&
            RegExp(
              r'^[a-f0-9]{64}\.engine\.part-\d+-\d+\.log$',
            ).hasMatch(path.basename(log))) {
          try {
            lines = await readPlaybackBuildLog(File(log));
          } on FileSystemException {
            // A diagnostic log can disappear during pruning. Keep its last
            // output without turning that into an engine preparation failure.
          }
        }
        status['lines'] = lines;
        if (status['phase'] != 'preparing') break;
        events.send(status);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } catch (error) {
      status['phase'] = cancelled ? 'cancelled' : 'failed';
      status['reason'] = '$error';
    } finally {
      if (job != nullptr) close?.call(job);
      await subscription.cancel();
      commands.close();
    }
    // Terminal delivery follows child cancellation/join, so retry cannot race
    // a still-running compiler from this request.
    events.send(status);
  }
}
