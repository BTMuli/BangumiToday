// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../core/cache/directory_cache.dart';

class LogStorageGroup {
  const LogStorageGroup({
    required this.day,
    required this.crashes,
    required this.bytes,
    required this.files,
    required this.protectedFiles,
    required this.directory,
  });

  final String day;
  final bool crashes;
  final int bytes;
  final int files;
  final int protectedFiles;
  final String directory;

  String get key => '${crashes ? 'crashes' : 'logs'}:$day';
  bool get canClear => files > protectedFiles;
}

class LogCleanupResult {
  const LogCleanupResult(this.deleted, this.skipped, this.failed);

  final int deleted;
  final int skipped;
  final int failed;
}

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

  Future<List<_LogEntry>> _readEntries(List<Directory> folders) async {
    var type = await FileSystemEntity.type(directory.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return [];
    if (type != FileSystemEntityType.directory) {
      throw FileSystemException('日志路径不是普通目录', directory.path);
    }
    var files = <_LogEntry>[];
    await for (var entity in directory.list(followLinks: false)) {
      var name = path.basename(entity.path);
      if (entity is File) {
        var entry = await _legacyEntry(entity, name);
        if (entry != null) files.add(entry);
      } else if (entity is Directory && name == 'state') {
        await _scan(entity, files, _sessionMarker, _LogKind.running);
      } else if (entity is Directory && _parseDay(name, padded: true) != null) {
        folders.add(entity);
        await _scan(entity, files, _sessionLog, _LogKind.log);
        var crashes = Directory(path.join(entity.path, 'crashes'));
        if (await FileSystemEntity.type(crashes.path, followLinks: false) ==
            FileSystemEntityType.directory) {
          folders.add(crashes);
          await _scan(crashes, files, _sessionCrash, _LogKind.crash);
        }
      }
    }
    return files;
  }

  Set<String?> _activeSessions(List<_LogEntry> entries) => {
    for (var entry in entries)
      if (entry.kind == _LogKind.running || entry.owner == pid.toString())
        entry.session,
  };

  Map<String?, DateTime> _latestSessionTimes(List<_LogEntry> entries) {
    var times = <String?, DateTime>{};
    for (var entry in entries) {
      var time = entry.crashTime ?? entry.modified;
      var previous = times[entry.session];
      if (previous == null || time.isAfter(previous)) {
        times[entry.session] = time;
      }
    }
    return times;
  }

  String _storageDay(_LogEntry entry, Map<String?, DateTime> times) {
    var folder = path.basename(entry.file.parent.path);
    // Unclean markers retain their startup write time when renamed. Associate
    // them with the last log write or actual dump time of the same session.
    var day = entry.kind == _LogKind.unclean
        ? times[entry.session] ?? entry.modified
        : entry.crashTime ?? _parseDay(entry.day ?? folder) ?? entry.modified;
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  bool _isCrash(_LogEntry entry) =>
      entry.kind == _LogKind.crash || entry.kind == _LogKind.unclean;

  String _storageKey(_LogEntry entry, Map<String?, DateTime> times) =>
      '${_isCrash(entry) ? 'crashes' : 'logs'}:${_storageDay(entry, times)}';

  String _groupDirectory(List<_LogEntry> entries) {
    // Prefer the actual log/dump location over auxiliary unclean markers.
    var records = entries.where((e) => e.kind != _LogKind.unclean).toList();
    if (records.isEmpty) records = entries;
    var folder = records.first.file.parent.path;
    for (var entry in records.skip(1)) {
      var parent = entry.file.parent.path;
      while (!path.equals(folder, parent) && !path.isWithin(folder, parent)) {
        folder = path.dirname(folder);
      }
    }
    return folder;
  }

  /// Manual management uses the same whitelist as automatic retention.
  Future<List<LogStorageGroup>> listGroups() async {
    var entries = await _readEntries([]);
    var active = _activeSessions(entries);
    var times = _latestSessionTimes(entries);
    var groups = <String, List<_LogEntry>>{};
    for (var entry in entries) {
      if (entry.kind == _LogKind.running) continue;
      groups.putIfAbsent(_storageKey(entry, times), () => []).add(entry);
    }
    var result = <LogStorageGroup>[
      for (var group in groups.values)
        LogStorageGroup(
          day: _storageDay(group.first, times),
          crashes: _isCrash(group.first),
          bytes: group.fold(0, (sum, entry) => sum + entry.size),
          files: group.length,
          protectedFiles: group.where((e) => active.contains(e.session)).length,
          directory: _groupDirectory(group),
        ),
    ];
    result.sort((a, b) => b.day.compareTo(a.day));
    return result;
  }

  /// Re-scan before deleting so a dialog's snapshot cannot remove newly active
  /// sessions. Running markers are never user-cleanable crash records.
  Future<LogCleanupResult> clearGroups(Set<String> keys) async {
    var entries = await _readEntries([]);
    var active = _activeSessions(entries);
    var times = _latestSessionTimes(entries);
    var deleted = 0;
    var skipped = 0;
    var failed = 0;
    for (var entry in entries) {
      if (entry.kind == _LogKind.running ||
          !keys.contains(_storageKey(entry, times))) {
        continue;
      }
      if (active.contains(entry.session)) {
        skipped++;
        continue;
      }
      try {
        var stat = await entry.file.stat();
        if (stat.type == FileSystemEntityType.notFound) continue;
        if (stat.size != entry.size ||
            stat.modified != entry.modified ||
            !await CacheFile(entry.file, stat).deleteIfUnchanged(directory)) {
          failed++;
        } else {
          deleted++;
        }
      } on FileSystemException catch (error) {
        failed++;
        onError(error);
      }
    }
    return LogCleanupResult(deleted, skipped, failed);
  }

  Future<int> cleanup({DateTime? now}) async {
    var current = now ?? DateTime.now();
    var regularCutoff = current.subtract(regularRetention);
    var crashCutoff = current.subtract(crashRetention);
    var files = <_LogEntry>[];
    var datedDirectories = <Directory>[];
    try {
      files = await _readEntries(datedDirectories);
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
          size: stat.size,
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
        size: stat.size,
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
        size: stat.size,
      );
    }
    var day = _parseDay(daily!.group(1)!);
    if (day == null) return null;
    return _LogEntry(
      file,
      stat.modified,
      _LogKind.log,
      day: _dayKey(day),
      size: stat.size,
    );
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
    required this.size,
  });

  final File file;
  final DateTime modified;
  final _LogKind kind;
  final String? session;
  final String? owner;
  final String? day;
  final DateTime? crashTime;
  final int size;
}
