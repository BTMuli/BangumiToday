// Dart imports:
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

class PlaybackTensorRtPreparation {
  PlaybackTensorRtPreparation(Map<String, dynamic> event)
    : phase = event['phase'] as String,
      completed = event['completed'] as int,
      task = event['task'] as String,
      reason = event['reason'] as String,
      lines = List<String>.unmodifiable(
        (event['lines'] as List? ?? const []).cast<String>(),
      );

  final String phase;
  final int completed;
  final String task;
  final String reason;
  final List<String> lines;
  String get label => task.isEmpty
      ? reason
      : '${math.min(completed + 1, 4)} / 4 · $task · $reason';
}

/// The native shim shares playback's cache and builder. Polling, log reads and
/// cancellation/join live in an isolate, without a Player or a video frame.
class PlaybackTensorRtPrecompile {
  SendPort? _control;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    _control?.send('cancel');
  }

  Future<void> run({
    required String bundle,
    required String runtime,
    required String cache,
    required void Function(PlaybackTensorRtPreparation) onProgress,
  }) async {
    _cancelled = false;
    var events = ReceivePort();
    try {
      await Isolate.spawn(
        _prepare,
        [events.sendPort, bundle, runtime, cache],
        onError: events.sendPort,
        onExit: events.sendPort,
      );
      PlaybackTensorRtPreparation? result;
      await for (var event in events) {
        if (event is SendPort) {
          _control = event;
          if (_cancelled) event.send('cancel');
        } else if (event is Map) {
          result = PlaybackTensorRtPreparation(
            Map<String, dynamic>.from(event),
          );
          onProgress(result);
        } else if (event is List) {
          throw StateError('引擎准备任务异常：${event.first}');
        } else if (event == null) {
          if (result?.phase != 'ready') {
            throw StateError(result?.reason ?? '引擎准备任务意外退出');
          }
          return;
        }
      }
    } finally {
      _control?.send('cancel');
      _control = null;
      events.close();
    }
  }

  static Future<void> _prepare(List<Object> request) async {
    var events = request[0] as SendPort;
    var bundle = request[1] as String;
    var runtime = request[2] as String;
    var cache = request[3] as String;
    var commands = ReceivePort();
    var cancelled = false;
    var subscription = commands.listen((_) => cancelled = true);
    events.send(commands.sendPort);
    Pointer<Void> job = nullptr;
    void Function(Pointer<Void>)? close;
    var status = <String, dynamic>{
      'phase': 'preparing',
      'completed': 0,
      'task': '',
      'reason': '正在启动引擎准备任务',
    };
    try {
      var library = DynamicLibrary.open(path.join(bundle, 'aji.dll'));
      var start = library
          .lookupFunction<
            Pointer<Void> Function(
              Pointer<Utf16>,
              Pointer<Utf16>,
              Pointer<Utf16>,
            ),
            Pointer<Void> Function(
              Pointer<Utf16>,
              Pointer<Utf16>,
              Pointer<Utf16>,
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
      job = using(
        (arena) => start(
          bundle.toNativeUtf16(allocator: arena),
          runtime.toNativeUtf16(allocator: arena),
          cache.toNativeUtf16(allocator: arena),
        ),
      );
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
