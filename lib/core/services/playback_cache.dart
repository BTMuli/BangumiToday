// Dart imports:
import 'dart:io';

// Package imports:
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../tools/log_tool.dart';
import 'file_service.dart';
import 'native_upscale_adapter.dart';

/// Configure writable caches before creating the renderer or opening media.
abstract final class PlaybackCache {
  static Future<void> configure(Player player) async {
    var adapter = NativeUpscaleAdapter(player.platform as NativePlayer);
    try {
      var root = await BTFileTool().getAppDataPath('cache/playback');
      var shaders = Directory(path.join(root, 'shaders'));
      var demuxer = Directory(path.join(root, 'demuxer'));
      await shaders.create(recursive: true);
      await demuxer.create(recursive: true);
      await adapter.command(['set', 'gpu-shader-cache-dir', shaders.path]);
      await adapter.command(['set', 'gpu-shader-cache', 'yes']);
      // media_kit enables disk caching; an unset mpv cache directory can fail
      // in embedded players and produces an error for every opened file.
      await adapter.command(['set', 'demuxer-cache-dir', demuxer.path]);
    } catch (error) {
      // Cache availability must not prevent media playback.
      BTLogTool.warn('配置播放缓存失败：$error');
    } finally {
      adapter.close();
    }
  }
}
