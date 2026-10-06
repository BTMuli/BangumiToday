// Dart imports:
import 'dart:async';
import 'dart:io';

// Project imports:
import '../../tools/log_tool.dart';
import '../cache/playback_shader_cache.dart';
import 'file_service.dart';

/// The main engine owns maintenance; playback engines share the disk directory.
class PlaybackShaderCacheService {
  PlaybackShaderCacheService._();

  static final instance = PlaybackShaderCacheService._();
  static const _cleanupInterval = Duration(hours: 1);

  PlaybackShaderCache? _cache;
  Timer? _timer;
  Future<void> _queue = Future.value();
  bool _maintaining = false;

  Future<PlaybackShaderCache> _getCache() async {
    return _cache ??= PlaybackShaderCache(
      Directory(await BTFileTool().getAppDataPath('cache/playback/shaders')),
    );
  }

  // Serialize maintenance, size queries and manual clearing in this engine.
  // mpv and other engines can still write files, so deletion is best effort.
  Future<T> _serialize<T>(
    Future<T> Function(PlaybackShaderCache cache) operation,
  ) {
    var result = _queue.then((_) async => operation(await _getCache()));
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Directory> prepareDirectory() {
    return _serialize((cache) async {
      await cache.ensureDirectory();
      return cache.directory;
    });
  }

  Future<int> getSize() => _serialize((cache) => cache.getSize());

  Future<ShaderCacheCleanupResult> clear() {
    return _serialize((cache) => cache.clear());
  }

  Future<void> start() async {
    if (_timer != null) return;
    _timer = Timer.periodic(_cleanupInterval, (_) => unawaited(_maintain()));
    await _maintain();
  }

  Future<void> _maintain() async {
    if (_maintaining) return;
    _maintaining = true;
    try {
      var result = await _serialize((cache) => cache.prune());
      if (result.deletedFiles > 0) {
        BTLogTool.info(
          '自动清理 Shader 缓存：${result.deletedFiles} 个文件，'
          '${BTFileTool.formatSize(result.deletedBytes)}',
        );
      }
      if (result.failedFiles > 0) {
        BTLogTool.warn('Shader 缓存有 ${result.failedFiles} 个文件暂时无法清理，稍后重试');
      }
    } catch (error) {
      // Disk cache maintenance must not interrupt playback or app startup.
      BTLogTool.warn('自动清理 Shader 缓存失败：$error');
    } finally {
      _maintaining = false;
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _queue;
  }
}
