// Dart imports:
import 'dart:io';

// Flutter imports:
import 'package:flutter/painting.dart';

// Package imports:
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../cache/cache_manager.dart';
import '../cache/directory_cache.dart';
import 'download_service.dart';
import 'file_service.dart';
import 'playback_shader_cache_service.dart';

enum AppCacheKind {
  data('应用数据缓存', '放送日历、条目详情和放送日期，下次使用时重新获取'),
  images('图片缓存', '封面和头像，下次使用时重新加载'),
  shaders('Shader 缓存', '下次使用时重新编译；自动清理 30 天未更新或超过 128 MiB 的缓存'),
  playback('播放器缓存', '视频播放缓冲文件，正在使用的文件可能暂时无法清理'),
  engines('TensorRT 引擎缓存', '保留已安装组件；下次 AI 超分可能需要重新编译引擎'),
  torrents('种子文件', '下载的 .torrent 文件，清理后可重新获取');

  const AppCacheKind(this.label, this.description);

  final String label;
  final String description;
}

/// The settings page owns selection and feedback; each category has one
/// matching size/cleanup boundary here.
class AppCacheService {
  const AppCacheService();

  Future<DirectoryCache> _directory(AppCacheKind kind) async {
    var files = BTFileTool();
    return switch (kind) {
      AppCacheKind.playback => DirectoryCache(
        Directory(await files.getAppDataPath('cache/playback/demuxer')),
        recursive: true,
      ),
      AppCacheKind.engines => PlaybackEngineCache(
        Directory(path.join(await playbackTensorRtDirectory(), 'engines')),
      ),
      AppCacheKind.torrents => DirectoryCache(
        Directory(BTDownloadTool.downloadDir),
        recursive: true,
      ),
      _ => throw ArgumentError.value(kind),
    };
  }

  Future<int> getSize(AppCacheKind kind) async => switch (kind) {
    AppCacheKind.data => BTCacheManager.instance.getDiskCacheBytes(),
    AppCacheKind.images => DefaultCacheManager().store.getCacheSize(),
    AppCacheKind.shaders => PlaybackShaderCacheService.instance.getSize(),
    _ => (await _directory(kind)).getSize(),
  };

  /// Returns files that could not be removed. A failed category never prevents
  /// the caller from cleaning the remaining selected categories.
  Future<int> clear(AppCacheKind kind) async {
    switch (kind) {
      case AppCacheKind.data:
        await BTCacheManager.instance.clear();
      case AppCacheKind.images:
        await DefaultCacheManager().emptyCache();
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      case AppCacheKind.shaders:
        return (await PlaybackShaderCacheService.instance.clear()).failedFiles;
      default:
        return (await _directory(kind)).clear();
    }
    return 0;
  }
}
