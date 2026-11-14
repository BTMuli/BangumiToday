// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

// Package imports:
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../models/playback/playback_export.dart';
import '../../models/playback/playback_item.dart';
import '../../models/playback/playback_upscale.dart';
import 'playback_assets.dart';
import 'playback_build_cancellation.dart';
import 'playback_tensorrt_resources.dart';

PlaybackPixels playbackExportSize(
  PlaybackVideoSource source,
  PlaybackUpscaleMode mode,
) {
  if (mode == PlaybackUpscaleMode.off) {
    throw ArgumentError('请选择超分档位');
  }
  var plan = playbackUpscalePlan(
    mode: mode,
    source: source,
    viewport: (
      width: source.width * 2.0,
      height: source.height * 2.0,
      dpr: 1.0,
    ),
    renderer: 'export GPU',
  );
  var output = plan.output;
  if (output == null) throw StateError(plan.reason);
  // H.264 4:2:0 requires even dimensions.
  return (width: output.width ~/ 2 * 2, height: output.height ~/ 2 * 2);
}

/// A dialog-scoped export, independent of the playback player and preferences.
class PlaybackVideoExport {
  bool _cancelled = false;
  bool _running = false;
  Pointer<Void> _job = nullptr;
  PlaybackBuildCancellation? _buildCancellation;
  void Function(Pointer<Void>)? _cancelNative;

  void cancel() {
    _cancelled = true;
    _buildCancellation?.cancel();
    if (_job != nullptr) _cancelNative?.call(_job);
  }

  Future<bool> run({
    required String source,
    required String destination,
    required PlaybackVideoSource video,
    required PlaybackUpscaleMode mode,
    required double fps,
    required PlaybackTensorRtResources resources,
    required void Function(double seconds) onProgress,
  }) async {
    if (_running) throw StateError('已有导出任务正在进行');
    if (!Platform.isWindows) throw UnsupportedError('视频超分导出仅支持 Windows');
    if (PlaybackItem.pathKey(source) == PlaybackItem.pathKey(destination)) {
      throw ArgumentError('导出文件不能覆盖源视频');
    }
    var format = PlaybackExportFormat.fromExtension(
      path.extension(destination),
    );
    if (format == null) throw ArgumentError('请选择支持的视频格式');
    if (!fps.isFinite || fps <= 0 || fps > 240) {
      throw StateError('无法确定源视频帧率');
    }
    var size = playbackExportSize(video, mode);
    _running = true;
    Directory? staging;
    void Function(Pointer<Void>)? close;
    try {
      staging = await Directory(
        path.dirname(destination),
      ).createTemp('.bangumi-export-');
      var output = File(
        path.join(staging.path, 'video${path.extension(destination)}'),
      );
      var shaders = await PlaybackAnime4kAssets(
        path.join(
          PlaybackAssets.directory(
            executable: Platform.resolvedExecutable,
            operatingSystem: Platform.operatingSystem,
          ),
          'shaders',
          'anime4k',
          'v4.0.1',
        ),
      ).load(mode);
      var filter = '';
      if (mode.isJanai) {
        if (!resources.canEnable) throw StateError('请先在设置中安装 TensorRT 组件');
        var config = File(path.join(staging.path, 'animejanai.conf'));
        var bundled = File(
          path.join(
            path.dirname(Platform.resolvedExecutable),
            'animejanai.conf',
          ),
        );
        var text = (await bundled.readAsString())
            .split('\n')
            .where(
              (line) => !RegExp(
                r'^\s*(backend|trt_dir|engine_cache|'
                r'build_cancel_event|stats|offline)\s*=',
              ).hasMatch(line),
            )
            .map((line) {
              for (var key in ['runtime_dir', 'model_dir']) {
                if (line.startsWith('$key=')) {
                  var absolute = path.normalize(
                    path.join(
                      bundled.parent.path,
                      line.substring(key.length + 1).trim(),
                    ),
                  );
                  return '$key=$absolute';
                }
              }
              return line;
            })
            .join('\n');
        var cancellation = _buildCancellation = PlaybackBuildCancellation(
          'Local\\BangumiToday.Export.$pid.'
          '${DateTime.now().microsecondsSinceEpoch}',
        );
        await config.writeAsString(
          '$text\nbackend=tensorrt\noffline=yes\n'
          'trt_dir=${resources.runtimeDirectory}\n'
          'engine_cache=${resources.engineDirectory}\n'
          'build_cancel_event=${cancellation.name}\n',
        );
        filter =
            'animejanai=slot=${mode.janaiSlot}:'
            'conf=%${utf8.encode(config.path).length}%${config.path}';
      }
      if (_cancelled) return false;
      var library = DynamicLibrary.open(
        path.join(
          path.dirname(Platform.resolvedExecutable),
          'media_kit_video_plugin.dll',
        ),
      );
      var start = library
          .lookupFunction<
            Pointer<Void> Function(Pointer<_ExportRequest>),
            Pointer<Void> Function(Pointer<_ExportRequest>)
          >('bt_video_export_start');
      var state = library
          .lookupFunction<
            Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('bt_video_export_state');
      var progress = library
          .lookupFunction<
            Double Function(Pointer<Void>),
            double Function(Pointer<Void>)
          >('bt_video_export_progress');
      var error = library
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Void>),
            Pointer<Utf8> Function(Pointer<Void>)
          >('bt_video_export_error');
      _cancelNative = library
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('bt_video_export_cancel');
      close = library
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('bt_video_export_close');
      _job = using((arena) {
        var request = arena<_ExportRequest>();
        request.ref
          ..source = source.toNativeUtf8(allocator: arena)
          ..target = output.path.toNativeUtf8(allocator: arena)
          ..shaders = shaders.join(';').toNativeUtf8(allocator: arena)
          ..filter = filter.toNativeUtf8(allocator: arena)
          ..format = format.muxer.toNativeUtf8(allocator: arena)
          ..width = size.width
          ..height = size.height
          ..fps = fps;
        return start(request);
      });
      if (_job == nullptr) throw StateError('无法启动视频导出');
      while (state(_job) == 0) {
        if (_cancelled) _cancelNative!(_job);
        onProgress(progress(_job));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (_cancelled || state(_job) == 2) return false;
      if (state(_job) != 1) {
        throw StateError('视频导出失败：${error(_job).toDartString()}');
      }
      close(_job);
      _job = nullptr;
      if (!await output.exists() || await output.length() == 0) {
        throw StateError('导出未生成视频文件');
      }
      // Same-volume rename publishes only a fully finalized video. On failure,
      // an existing destination is left intact and the error is shown.
      await output.rename(destination);
      return true;
    } finally {
      if (_job != nullptr) close?.call(_job);
      _job = nullptr;
      _buildCancellation?.dispose();
      _buildCancellation = null;
      _cancelNative = null;
      _running = false;
      if (staging != null && await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }
}

final class _ExportRequest extends Struct {
  external Pointer<Utf8> source;
  external Pointer<Utf8> target;
  external Pointer<Utf8> shaders;
  external Pointer<Utf8> filter;
  external Pointer<Utf8> format;
  @Int32()
  external int width;
  @Int32()
  external int height;
  @Double()
  external double fps;
}
