// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:logger/logger.dart';

// Project imports:
import 'log_identity.dart';
import 'log_retention.dart';

/// 每条记录同步追加，避免原生崩溃时丢失 IOSink 中尚未提交的日志。
/// 不同 Flutter 引擎写不同文件，跨午夜时自动切换日期。
/// 文件使用紧凑格式，不重复保存控制台的装饰边框和普通调用栈。
class BTDurableLogOutput extends LogOutput {
  BTDurableLogOutput(
    this.directory,
    this.scope, {
    required this.onError,
    BTLogIdentity? identity,
  }) : identity = identity ?? BTLogIdentity.current;

  final String directory;
  final String scope;
  final BTLogIdentity identity;
  final void Function(FileSystemException) onError;
  final _printer = SimplePrinter(printTime: true, colors: false);

  Timer? _cleanupTimer;
  Future<void>? _cleanupTask;
  Directory? _outputDirectory;
  RandomAccessFile? _output;
  String? _outputPath;

  @override
  Future<void> init() async {
    if (scope != 'main') return;
    _scheduleCleanup();
    _cleanupTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _scheduleCleanup(),
    );
  }

  void _scheduleCleanup() {
    if (_cleanupTask != null) return;
    _cleanupTask = _cleanup();
    unawaited(_cleanupTask);
  }

  Future<void> _cleanup() async {
    try {
      await BTLogRetention(Directory(directory), onError: onError).cleanup();
    } finally {
      _cleanupTask = null;
    }
  }

  @override
  Future<void> destroy() async {
    _cleanupTimer?.cancel();
    await _cleanupTask;
    _closeOutput(flush: true);
  }

  @override
  void output(OutputEvent event) {
    var now = DateTime.now();
    var file = File(identity.filePath(directory, scope, now));
    try {
      if (_outputDirectory?.path != file.parent.path) {
        file.parent.createSync(recursive: true);
        _outputDirectory = file.parent;
      }
      if (_outputPath != file.path) {
        _closeOutput();
        _output = file.openSync(mode: FileMode.append);
        _outputPath = file.path;
      }
      // Keep crash diagnostics synchronous without opening a handle per entry.
      var lines = _printer.log(event.origin);
      var stackTrace = event.origin.stackTrace;
      if (stackTrace != null) lines.add(stackTrace.toString());
      _output!.writeStringSync('${lines.join('\n')}\n');
      if (event.level.index >= Level.warning.index) _output!.flushSync();
    } on FileSystemException catch (error) {
      // 文件输出自身失败时不能再次调用 logger，避免递归。
      _closeOutput();
      onError(error);
    }
  }

  void _closeOutput({bool flush = false}) {
    var output = _output;
    _output = null;
    _outputPath = null;
    if (output == null) return;
    try {
      try {
        if (flush) output.flushSync();
      } finally {
        output.closeSync();
      }
    } on FileSystemException catch (error) {
      onError(error);
    }
  }
}
