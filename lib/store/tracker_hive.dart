// Dart imports:
import 'dart:convert';
import 'dart:typed_data';

// Package imports:
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:hive/hive.dart';

// Project imports:
import '../core/services/bt_engine_client.dart';
import '../database/app/app_config.dart';
import '../models/app/bt_tracker_config.dart';
import '../models/hive/tracker_model.dart';
import '../tools/log_tool.dart';

const _maxTrackerResponseBytes = 1024 * 1024;
const _maxResolvedTrackers = 512;
const _trackerUpdateInterval = Duration(hours: 24);
const _trackerRequestTimeout = Duration(seconds: 30);

String normalizeTrackerUrl(String rawUrl) {
  if (rawUrl.isEmpty || rawUrl.length > 2048) {
    throw const FormatException('Tracker URL length is invalid');
  }
  if (RegExp(r'[\x00-\x20\x7f]').hasMatch(rawUrl)) {
    throw const FormatException('Tracker URL contains whitespace');
  }
  var uri = Uri.parse(rawUrl);
  var scheme = uri.scheme.toLowerCase();
  if (!{'udp', 'http', 'https'}.contains(scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const FormatException('Tracker URL is invalid');
  }
  if (scheme == 'udp' && !uri.hasPort) {
    throw const FormatException('UDP Tracker URL requires a port');
  }
  if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
    throw const FormatException('Tracker URL port is invalid');
  }

  var host = uri.host.toLowerCase();
  if (host.contains(':')) host = '[$host]';
  var includePort =
      uri.hasPort &&
      !((scheme == 'http' && uri.port == 80) ||
          (scheme == 'https' && uri.port == 443));
  var result = '$scheme://$host';
  if (includePort) result += ':${uri.port}';
  result += uri.path.isEmpty ? '/' : uri.path;
  if (uri.hasQuery) result += '?${uri.query}';
  if (result.length > 2048) {
    throw const FormatException('Tracker URL length is invalid');
  }
  return result;
}

List<String> parseTrackerText(String text, {bool allowCommas = false}) {
  var separator = allowCommas ? RegExp(r'[,\r\n]+') : RegExp(r'[\r\n]+');
  var result = <String>[];
  var seen = <String>{};
  for (var rawLine in text.split(separator)) {
    var line = rawLine.trim();
    if (line.startsWith('\uFEFF')) line = line.substring(1).trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    try {
      var normalized = normalizeTrackerUrl(line);
      if (seen.add(normalized)) result.add(normalized);
    } on FormatException {
      // A malformed entry does not invalidate the rest of the source.
    }
  }
  return result;
}

List<String> mergeTrackers(
  List<String> manualTrackers,
  Iterable<List<String>> sourceSnapshots,
) {
  var result = <String>[];
  var seen = <String>{};
  void append(Iterable<String> trackers) {
    for (var tracker in trackers) {
      if (result.length >= _maxResolvedTrackers) return;
      try {
        var normalized = normalizeTrackerUrl(tracker);
        if (seen.add(normalized)) result.add(normalized);
      } on FormatException {
        // Persisted snapshots are untrusted and are validated again here.
      }
    }
  }

  append(manualTrackers);
  for (var snapshot in sourceSnapshots) {
    append(snapshot);
    if (result.length >= _maxResolvedTrackers) break;
  }
  return result;
}

class TrackerHive extends ChangeNotifier {
  TrackerHive._();

  static final TrackerHive instance = TrackerHive._();

  factory TrackerHive() => instance;

  static Box<TrackerHiveModel> get box => Hive.box<TrackerHiveModel>('tracker');

  final Dio client = Dio();
  BtTrackerConfig _config = const BtTrackerConfig();
  Future<void>? _refreshOperation;

  BtTrackerConfig get config => _config;
  bool get refreshing => _refreshOperation != null;

  List<String> get effectiveTrackers {
    var snapshots = _config.sources.map(
      (source) => box.get(source)?.trackerList ?? const <String>[],
    );
    return mergeTrackers(_config.manualTrackers, snapshots);
  }

  List<Uri> getTrackerList() {
    return effectiveTrackers.map(Uri.parse).toList(growable: false);
  }

  Future<void> init() async {
    _config = await BtsAppConfig().readBtTrackerConfig();
    for (var source in _config.sources) {
      if (box.get(source) == null) {
        await box.put(
          source,
          TrackerHiveModel(url: source, updateTime: '', trackerList: []),
        );
      }
    }
  }

  Future<void> updateConfig(BtTrackerConfig config) async {
    config.validate();
    var normalizedManual = mergeTrackers(config.manualTrackers, const []);
    _config = config.copyWith(manualTrackers: normalizedManual);
    for (var source in _config.sources) {
      if (box.get(source) == null) {
        await box.put(
          source,
          TrackerHiveModel(url: source, updateTime: '', trackerList: []),
        );
      }
    }
    await BtsAppConfig().writeBtTrackerConfig(_config);
    await _applyToEngine();
    notifyListeners();
  }

  Future<void> checkUpdate() => refresh();

  Future<void> checkUpdateSingle(String url) async {
    if (!_config.sources.contains(url)) return;
    await refresh(force: true, sources: [url]);
  }

  Future<void> refresh({bool force = false, List<String>? sources}) {
    var running = _refreshOperation;
    if (running != null) return running;
    var operation = _refresh(force: force, sources: sources);
    _refreshOperation = operation;
    notifyListeners();
    return operation.whenComplete(() {
      _refreshOperation = null;
      notifyListeners();
    });
  }

  Future<void> _refresh({
    required bool force,
    required List<String>? sources,
  }) async {
    if (!force && !_config.autoUpdate) return;
    var now = DateTime.now();
    var lastSuccess = _config.lastUpdateSuccessAt;
    if (!force &&
        lastSuccess != null &&
        now.difference(lastSuccess) < _trackerUpdateInterval) {
      return;
    }

    var selectedSources = sources ?? _config.sources;
    _config = _config.copyWith(lastUpdateAttemptAt: now);
    await BtsAppConfig().writeBtTrackerConfig(_config);
    var results = await Future.wait(selectedSources.map(_fetchSource));
    var successes = 0;
    var failures = 0;
    var sourceEtags = Map<String, String>.of(_config.sourceEtags);
    var sourceLastModified = Map<String, String>.of(_config.sourceLastModified);
    for (var result in results) {
      if (result.trackers == null) {
        failures++;
        continue;
      }
      successes++;
      if (!result.notModified) {
        await box.put(
          result.source,
          TrackerHiveModel(
            url: result.source,
            updateTime: now.toUtc().toIso8601String(),
            trackerList: result.trackers!,
          ),
        );
      }
      _replaceValidator(sourceEtags, result.source, result.etag);
      _replaceValidator(sourceLastModified, result.source, result.lastModified);
    }

    String? error;
    if (successes == 0 && selectedSources.isNotEmpty) {
      error = '所有 Tracker 来源更新失败，已保留上次成功结果';
    } else if (failures > 0) {
      error = '$failures 个 Tracker 来源更新失败，已保留对应旧结果';
    }
    _config = _config.copyWith(
      lastUpdateSuccessAt: successes > 0 ? now : _config.lastUpdateSuccessAt,
      lastUpdateError: error,
      sourceEtags: sourceEtags,
      sourceLastModified: sourceLastModified,
    );
    await BtsAppConfig().writeBtTrackerConfig(_config);
    await _applyToEngine();
    BTLogTool.info(
      'Tracker 更新完成：$successes 个来源成功，$failures 个来源失败，'
      '合并 ${effectiveTrackers.length} 条',
    );
    notifyListeners();
  }

  Future<_TrackerFetchResult> _fetchSource(String source) async {
    try {
      var headers = <String, dynamic>{};
      var etag = _config.sourceEtags[source];
      var lastModified = _config.sourceLastModified[source];
      if (etag != null) headers['If-None-Match'] = etag;
      if (lastModified != null) headers['If-Modified-Since'] = lastModified;
      var response = await client.get<ResponseBody>(
        source,
        options: Options(
          connectTimeout: _trackerRequestTimeout,
          receiveTimeout: _trackerRequestTimeout,
          responseType: ResponseType.stream,
          followRedirects: true,
          maxRedirects: 5,
          validateStatus: (status) => status == 200 || status == 304,
          headers: headers,
        ),
      );
      var responseEtag = response.headers.value('etag');
      var responseLastModified = response.headers.value('last-modified');
      if (response.statusCode == 304) {
        var snapshot = box.get(source)?.trackerList;
        if (snapshot == null || snapshot.isEmpty) {
          throw const FormatException('Tracker source has no cached snapshot');
        }
        return _TrackerFetchResult(
          source,
          snapshot,
          notModified: true,
          etag: responseEtag ?? etag,
          lastModified: responseLastModified ?? lastModified,
        );
      }
      var body = response.data;
      if (response.statusCode != 200 || body == null) {
        throw const FormatException('Tracker source returned no content');
      }
      var bytes = BytesBuilder(copy: false);
      await for (var chunk in body.stream) {
        if (bytes.length + chunk.length > _maxTrackerResponseBytes) {
          throw const FormatException('Tracker source response is too large');
        }
        bytes.add(chunk);
      }
      var trackers = parseTrackerText(utf8.decode(bytes.takeBytes()));
      if (trackers.isEmpty) {
        throw const FormatException('Tracker source contains no valid entries');
      }
      return _TrackerFetchResult(
        source,
        trackers,
        etag: responseEtag,
        lastModified: responseLastModified,
      );
    } catch (error) {
      BTLogTool.warn('Tracker 来源更新失败：${_sourceLabel(source)}');
      return _TrackerFetchResult(source, null);
    }
  }

  Future<void> _applyToEngine() async {
    if (!BtEngineClient.instance.isReady) return;
    try {
      await BtEngineClient.instance.configure({
        'additionalTrackers': effectiveTrackers,
      });
    } catch (error) {
      BTLogTool.warn('Tracker 配置暂未应用到下载引擎');
    }
  }

  String _sourceLabel(String source) {
    var uri = Uri.tryParse(source);
    if (uri == null || uri.host.isEmpty) return '无效来源';
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  void _replaceValidator(
    Map<String, String> validators,
    String source,
    String? value,
  ) {
    if (value == null || value.isEmpty) {
      validators.remove(source);
    } else {
      validators[source] = value;
    }
  }
}

class _TrackerFetchResult {
  const _TrackerFetchResult(
    this.source,
    this.trackers, {
    this.notModified = false,
    this.etag,
    this.lastModified,
  });

  final String source;
  final List<String>? trackers;
  final bool notModified;
  final String? etag;
  final String? lastModified;
}
