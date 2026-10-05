// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

/// 只清理应用生成的日志；崩溃关联日志和转储保留 30 天。
class BTLogRetention {
  BTLogRetention(this.directory, {required this.onError});

  static const regularRetention = Duration(days: 7);
  static const crashRetention = Duration(days: 30);

  static final _dailyLog = RegExp(
    r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:-[a-zA-Z0-9_-]+)?\.log$',
  );
  static final _nativeFile = RegExp(
    r'^native-([1-9]\d*)\.(log|running(?:\.unclean)?)$',
  );
  static final _crashArtifact = RegExp(
    r'^native-([1-9]\d*)-(\d{8}-\d{6}(?:-\d{3})?)'
    r'\.dmp(?:\.triage\.dmp(?:\.partial)?|\.partial|\.txt)?$',
  );

  final Directory directory;
  final void Function(FileSystemException) onError;

  Future<int> cleanup({DateTime? now}) async {
    var current = now ?? DateTime.now();
    var regularCutoff = current.subtract(regularRetention);
    var crashCutoff = current.subtract(crashRetention);
    var files = <String, ({File file, DateTime modified})>{};
    try {
      await for (var entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        var name = path.basename(entity.path);
        if (!_dailyLog.hasMatch(name) &&
            !_nativeFile.hasMatch(name) &&
            !_crashArtifact.hasMatch(name)) {
          continue;
        }
        var stat = await entity.stat();
        if (stat.type == FileSystemEntityType.file) {
          files[name] = (file: entity, modified: stat.modified);
        }
      }
    } on FileSystemException catch (error) {
      // 扫描不完整时不删除，避免漏掉保护关联日志的崩溃证据。
      onError(error);
      return 0;
    }

    var activePids = {pid.toString()};
    var crashTimes = <String, DateTime>{};
    var crashDays = <String, DateTime>{};
    var artifactTimes = <String, DateTime>{};
    void recordCrash(String owner, DateTime time) {
      var previous = crashTimes[owner];
      if (previous == null || time.isAfter(previous)) {
        crashTimes[owner] = time;
      }
      if (time.isBefore(crashCutoff)) return;
      var day = _dayKey(time);
      previous = crashDays[day];
      if (previous == null || time.isAfter(previous)) crashDays[day] = time;
    }

    for (var entry in files.entries) {
      var native = _nativeFile.firstMatch(entry.key);
      if (native != null) {
        var owner = native.group(1)!;
        if (native.group(2) == 'running') {
          activePids.add(owner);
        } else if (native.group(2) == 'running.unclean') {
          var time = entry.value.modified;
          var logTime = files['native-$owner.log']?.modified;
          // 标记创建于进程启动时；日志末次写入更接近异常退出时间。
          if (logTime != null && logTime.isAfter(time)) time = logTime;
          recordCrash(owner, time);
        }
        continue;
      }
      var crash = _crashArtifact.firstMatch(entry.key);
      if (crash == null) continue;
      var timestamp = crash.group(2)!;
      var parsed = _parseCrashTime(
        timestamp.length == 19 ? timestamp : '$timestamp-000',
      );
      if (parsed == null) continue;
      // 旧版名称记录启动时间，使用文件修改时间；新版记录实际崩溃时间。
      var time = timestamp.length == 19 ? parsed : entry.value.modified;
      artifactTimes[entry.key] = time;
      recordCrash(crash.group(1)!, time);
    }

    var removed = 0;
    for (var entry in files.entries) {
      var cutoff = regularCutoff;
      var modified = entry.value.modified;
      var native = _nativeFile.firstMatch(entry.key);
      if (native != null) {
        var owner = native.group(1)!;
        // 原生崩溃处理器长期持有日志句柄，不能删除活跃进程的日志。
        if (activePids.contains(owner)) continue;
        var crashTime = crashTimes[owner];
        if (crashTime != null) {
          cutoff = crashCutoff;
          if (crashTime.isAfter(modified)) modified = crashTime;
        }
      } else if (_crashArtifact.hasMatch(entry.key)) {
        var time = artifactTimes[entry.key];
        if (time == null) continue;
        modified = time;
        cutoff = crashCutoff;
      } else {
        var daily = _dailyLog.firstMatch(entry.key)!;
        var day = DateTime(
          int.parse(daily.group(1)!),
          int.parse(daily.group(2)!),
          int.parse(daily.group(3)!),
        );
        if (day.year != int.parse(daily.group(1)!) ||
            day.month != int.parse(daily.group(2)!) ||
            day.day != int.parse(daily.group(3)!)) {
          continue;
        }
        var crashTime = crashDays[_dayKey(day)];
        if (crashTime != null) {
          cutoff = crashCutoff;
          if (crashTime.isAfter(modified)) modified = crashTime;
        }
      }
      if (!modified.isBefore(cutoff)) continue;
      try {
        await entry.value.file.delete();
        removed++;
      } on FileSystemException catch (error) {
        // 被占用、权限不足或被另一轮清理删除，都不影响后续文件。
        onError(error);
      }
    }
    return removed;
  }

  static String _dayKey(DateTime time) =>
      '${time.year}-${time.month}-${time.day}';

  static DateTime? _parseCrashTime(String timestamp) {
    var iso =
        '${timestamp.substring(0, 4)}-${timestamp.substring(4, 6)}-'
        '${timestamp.substring(6, 8)}T${timestamp.substring(9, 11)}:'
        '${timestamp.substring(11, 13)}:${timestamp.substring(13, 15)}.'
        '${timestamp.substring(16)}';
    var time = DateTime.tryParse(iso);
    // 拒绝 DateTime 自动归一化的无效日期，保留未知命名文件。
    return time?.toIso8601String() == iso ? time : null;
  }
}
