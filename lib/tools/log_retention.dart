// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

/// 按运行标识保留日志，同时识别旧版平铺文件；未知文件不会被删除。
class BTLogRetention {
  BTLogRetention(this.directory, {required this.onError});

  static const regularRetention = Duration(days: 7);
  static const crashRetention = Duration(days: 30);

  static const _sessionPattern = r'(\d{8}-\d{6}-\d{3})-([1-9]\d*)';
  static final _sessionLog = RegExp(
    '^$_sessionPattern-(?:main|native|playback-[a-zA-Z0-9_-]+)\\.log\$',
  );
  static final _sessionMarker = RegExp(
    '^$_sessionPattern\\.(running(?:\\.unclean)?)\$',
  );
  static final _sessionCrash = RegExp(
    '^$_sessionPattern-crash-(\\d{8}-\\d{6}-\\d{3})'
    r'\.dmp(?:\.triage\.dmp(?:\.partial)?|\.partial|\.txt)?$',
  );
  static final _dailyLog = RegExp(
    r'^(\d{4}-\d{1,2}-\d{1,2})(?:-[a-zA-Z0-9_-]+)?\.log$',
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
    var files = <_LogEntry>[];
    var datedDirectories = <Directory>[];
    try {
      await for (var entity in directory.list(followLinks: false)) {
        var name = path.basename(entity.path);
        if (entity is File) {
          var entry = await _legacyEntry(entity, name);
          if (entry != null) files.add(entry);
        } else if (entity is Directory && name == 'state') {
          await _scan(entity, files, _sessionMarker, _LogKind.running);
        } else if (entity is Directory &&
            _parseDay(name, padded: true) != null) {
          datedDirectories.add(entity);
          await _scan(entity, files, _sessionLog, _LogKind.log);
          var crashes = Directory(path.join(entity.path, 'crashes'));
          if (await FileSystemEntity.type(crashes.path, followLinks: false) ==
              FileSystemEntityType.directory) {
            datedDirectories.add(crashes);
            await _scan(crashes, files, _sessionCrash, _LogKind.crash);
          }
        }
      }
    } on FileSystemException catch (error) {
      // 不完整的扫描可能遗漏活跃标记或崩溃证据，因此整轮停止删除。
      onError(error);
      return 0;
    }

    var active = <String>{};
    var latestWrites = <String, DateTime>{};
    var crashTimes = <String, DateTime>{};
    var crashDays = <String, DateTime>{};
    void recordLatest(Map<String, DateTime> times, String key, DateTime time) {
      var previous = times[key];
      if (previous == null || time.isAfter(previous)) times[key] = time;
    }

    for (var entry in files) {
      var session = entry.session;
      if (session == null) continue;
      if (entry.kind == _LogKind.running || entry.owner == pid.toString()) {
        active.add(session);
      }
      if (entry.kind == _LogKind.log) {
        recordLatest(latestWrites, session, entry.modified);
      }
    }
    for (var entry in files) {
      if (entry.kind != _LogKind.unclean && entry.kind != _LogKind.crash) {
        continue;
      }
      var time = entry.crashTime ?? entry.modified;
      var lastWrite = latestWrites[entry.session];
      if (entry.kind == _LogKind.unclean &&
          lastWrite != null &&
          lastWrite.isAfter(time)) {
        time = lastWrite;
      }
      recordLatest(crashTimes, entry.session!, time);
      if (!time.isBefore(crashCutoff)) {
        recordLatest(crashDays, _dayKey(time), time);
      }
    }

    var removed = 0;
    for (var entry in files) {
      // 活跃运行按完整标识保护；当前进程同时保护没有标记的 Dart 日志。
      if (entry.owner == pid.toString() || active.contains(entry.session)) {
        continue;
      }
      var crashTime = crashTimes[entry.session];
      // 旧版按天合并，无法精确关联运行，仍保护崩溃当天的旧日志。
      if (entry.session == null) crashTime = crashDays[entry.day];
      var cutoff = crashTime != null || entry.kind == _LogKind.crash
          ? crashCutoff
          : regularCutoff;
      var modified = entry.crashTime ?? entry.modified;
      if (crashTime != null && crashTime.isAfter(modified)) {
        modified = crashTime;
      }
      if (!modified.isBefore(cutoff)) continue;
      try {
        await entry.file.delete();
        removed++;
      } on FileSystemException catch (error) {
        onError(error);
      }
    }
    // 只移除已扫描的空日期/转储目录，不递归删除，不触碰用户文件。
    for (var folder in datedDirectories.reversed) {
      var name = path.basename(folder.path);
      var dayName = name == 'crashes'
          ? path.basename(folder.parent.path)
          : name;
      var day = _parseDay(dayName, padded: true)!;
      if (!day.isBefore(regularCutoff) ||
          active.any(
            (session) => session.startsWith(dayName.replaceAll('-', '')),
          )) {
        continue;
      }
      try {
        if (await folder.list(followLinks: false).isEmpty) {
          await folder.delete();
        }
      } on FileSystemException catch (error) {
        if (await folder.exists()) onError(error);
      }
    }
    return removed;
  }

  Future<void> _scan(
    Directory folder,
    List<_LogEntry> files,
    RegExp pattern,
    _LogKind kind,
  ) async {
    await for (var entity in folder.list(followLinks: false)) {
      if (entity is! File) continue;
      var match = pattern.firstMatch(path.basename(entity.path));
      if (match == null || _parseTimestamp(match.group(1)!) == null) continue;
      var actualKind = kind;
      DateTime? crashTime;
      if (kind == _LogKind.running && match.group(3) == 'running.unclean') {
        actualKind = _LogKind.unclean;
      } else if (kind == _LogKind.crash) {
        crashTime = _parseTimestamp(match.group(3)!);
        if (crashTime == null) continue;
      }
      var stat = await entity.stat();
      if (stat.type != FileSystemEntityType.file) continue;
      files.add(
        _LogEntry(
          entity,
          stat.modified,
          actualKind,
          session: '${match.group(1)}-${match.group(2)}',
          owner: match.group(2),
          crashTime: crashTime,
        ),
      );
    }
  }

  Future<_LogEntry?> _legacyEntry(File file, String name) async {
    var native = _nativeFile.firstMatch(name);
    var crash = _crashArtifact.firstMatch(name);
    var daily = _dailyLog.firstMatch(name);
    if (native == null && crash == null && daily == null) return null;
    var stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) return null;
    if (native != null) {
      var kind = switch (native.group(2)) {
        'running' => _LogKind.running,
        'running.unclean' => _LogKind.unclean,
        _ => _LogKind.log,
      };
      return _LogEntry(
        file,
        stat.modified,
        kind,
        session: 'legacy-${native.group(1)}',
        owner: native.group(1),
      );
    }
    if (crash != null) {
      var timestamp = crash.group(2)!;
      var time = _parseTimestamp(
        timestamp.length == 19 ? timestamp : '$timestamp-000',
      );
      if (time == null) return null;
      return _LogEntry(
        file,
        stat.modified,
        _LogKind.crash,
        session: 'legacy-${crash.group(1)}',
        owner: crash.group(1),
        crashTime: timestamp.length == 19 ? time : stat.modified,
      );
    }
    var day = _parseDay(daily!.group(1)!);
    if (day == null) return null;
    return _LogEntry(file, stat.modified, _LogKind.log, day: _dayKey(day));
  }

  static String _dayKey(DateTime time) =>
      '${time.year}-${time.month}-${time.day}';

  static DateTime? _parseDay(String name, {bool padded = false}) {
    var pattern = padded ? r'^\d{4}-\d{2}-\d{2}$' : r'^\d{4}-\d{1,2}-\d{1,2}$';
    if (!RegExp(pattern).hasMatch(name)) return null;
    var parts = name.split('-').map(int.parse).toList();
    var time = DateTime(parts[0], parts[1], parts[2]);
    if (time.year != parts[0] ||
        time.month != parts[1] ||
        time.day != parts[2]) {
      return null;
    }
    return time;
  }

  static DateTime? _parseTimestamp(String timestamp) {
    var iso =
        '${timestamp.substring(0, 4)}-${timestamp.substring(4, 6)}-'
        '${timestamp.substring(6, 8)}T${timestamp.substring(9, 11)}:'
        '${timestamp.substring(11, 13)}:${timestamp.substring(13, 15)}.'
        '${timestamp.substring(16)}';
    var time = DateTime.tryParse(iso);
    return time?.toIso8601String() == iso ? time : null;
  }
}

enum _LogKind { log, running, unclean, crash }

class _LogEntry {
  const _LogEntry(
    this.file,
    this.modified,
    this.kind, {
    this.session,
    this.owner,
    this.day,
    this.crashTime,
  });

  final File file;
  final DateTime modified;
  final _LogKind kind;
  final String? session;
  final String? owner;
  final String? day;
  final DateTime? crashTime;
}
