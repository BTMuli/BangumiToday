// Dart imports:
import 'dart:ffi';
import 'dart:io';

// Package imports:
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:win32/win32.dart';

/// 使用进程创建时间关联不同 Flutter 引擎和原生日志，避免 PID 复用混写。
class BTLogIdentity {
  BTLogIdentity(DateTime startedAt, this.processId)
    : startedAt = startedAt.toLocal();

  static final current = BTLogIdentity(_processStartedAt(), pid);

  final DateTime startedAt;
  final int processId;

  late final String session = _sessionId();

  String _sessionId() {
    var time = startedAt;
    return '${day(time).replaceAll('-', '')}-'
        '${_pad(time.hour)}${_pad(time.minute)}${_pad(time.second)}-'
        '${_pad(time.millisecond, 3)}-$processId';
  }

  String filePath(String directory, String scope, DateTime time) =>
      path.join(directory, day(time), '$session-$scope.log');

  static String day(DateTime time) =>
      '${_pad(time.year, 4)}-${_pad(time.month)}-${_pad(time.day)}';

  static String _pad(int value, [int width = 2]) =>
      value.toString().padLeft(width, '0');

  static DateTime _processStartedAt() {
    if (!Platform.isWindows) return DateTime.now();
    var times = calloc<FILETIME>(4);
    try {
      var result = GetProcessTimes(
        GetCurrentProcess(),
        times,
        times + 1,
        times + 2,
        times + 3,
      );
      if (!result.value) return DateTime.now();
      var ticks = (times.ref.dwHighDateTime << 32) | times.ref.dwLowDateTime;
      return DateTime.fromMicrosecondsSinceEpoch(
        ticks ~/ 10 - 11644473600000000,
        isUtc: true,
      ).toLocal();
    } finally {
      calloc.free(times);
    }
  }
}
