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

  Timer? _cleanupTimer;
  Future<void>? _cleanupTask;
  Directory? _outputDirectory;

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
      file.writeAsStringSync(
        '${event.lines.join('\n')}\n',
        mode: FileMode.append,
        flush: event.level.index >= Level.warning.index,
      );
    } on FileSystemException catch (error) {
      // 文件输出自身失败时不能再次调用 logger，避免递归。
      onError(error);
    }
  }
}
