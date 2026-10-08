// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../../models/playback/playback_janai_benchmark.dart';

/// Bundled reference data works offline. Refresh only on explicit request;
/// matching remains local and never uploads the user's hardware details.
class PlaybackJanaiBenchmarks {
  PlaybackJanaiBenchmarks({
    required this.directory,
    required this.onChanged,
    required this.loadBundled,
  });

  final String directory;
  final void Function() onChanged;
  final Future<String> Function() loadBundled;
  PlaybackJanaiBenchmarkCatalog? catalog;
  String? error;
  bool updating = false;
  bool _disposed = false;
  Future<void>? _initialization;
  Future<void>? _refresh;
  HttpClient? _client;
  File get _cache => File(path.join(directory, 'benchmarks.json'));

  PlaybackJanaiBenchmarkCatalog _decode(String text) =>
      PlaybackJanaiBenchmarkCatalog.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
      );

  Future<void> initialize() =>
      _disposed ? Future.value() : _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      var bundled = _decode(await loadBundled());
      if (_disposed) return;
      catalog = bundled;
      try {
        if (await _cache.exists() && await _cache.length() <= 2097152) {
          var cached = _decode(await _cache.readAsString());
          if (!_disposed && cached.generatedAt.isAfter(bundled.generatedAt)) {
            catalog = cached;
          }
        }
      } catch (_) {
        // Corrupt or interrupted cache writes do not discard the snapshot.
      }
    } catch (_) {
      error = 'benchmark 数据暂不可用';
    } finally {
      if (!_disposed) onChanged();
    }
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    return _refresh ??= _update().whenComplete(() => _refresh = null);
  }

  Future<void> _update() async {
    updating = true;
    error = null;
    onChanged();
    try {
      await initialize();
      if (_disposed) return;
      var client = _client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      var request = await client.getUrl(
        Uri.parse(PlaybackJanaiBenchmarkCatalog.dataUrl),
      );
      var response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      var bytes = await response
          .fold<List<int>>([], (bytes, chunk) {
            if (bytes.length + chunk.length > 2097152) {
              throw const FormatException('benchmark 数据过大');
            }
            return bytes..addAll(chunk);
          })
          .timeout(const Duration(seconds: 15));
      var text = utf8.decode(bytes);
      var updated = _decode(text);
      if (_disposed) return;
      if (catalog != null &&
          updated.generatedAt.isBefore(catalog!.generatedAt)) {
        throw const FormatException('benchmark 数据版本过旧');
      }
      catalog = updated;
      error = null;
      try {
        await _cache.parent.create(recursive: true);
        var temporary = File(
          '${_cache.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
        );
        try {
          await temporary.writeAsString(text, flush: true);
          await temporary.rename(_cache.path);
        } finally {
          if (await temporary.exists()) await temporary.delete();
        }
      } catch (_) {
        error = 'benchmark 已更新，无法保存离线缓存';
      }
    } catch (_) {
      error = catalog == null
          ? 'benchmark 更新失败，请稍后重试'
          : 'benchmark 更新失败，继续使用已有数据';
    } finally {
      _client?.close(force: true);
      _client = null;
      updating = false;
      if (!_disposed) onChanged();
    }
  }

  void dispose() {
    _disposed = true;
    _client?.close(force: true);
  }
}
