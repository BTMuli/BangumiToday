// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// Project imports:
import '../../models/playback/playback_janai_status.dart';
import '../../models/playback/playback_upscale.dart';
import '../utils/playback_build_log.dart';
import 'native_upscale_adapter.dart';
import 'playback_tensorrt_resources.dart';
import 'playback_upscaler.dart';

class NativePlaybackUpscaleBackend implements PlaybackUpscaleBackend {
  NativePlaybackUpscaleBackend(
    this.player,
    this.video, {
    bool Function()? tensorRtEnabled,
    required this.tensorRtResources,
  }) : tensorRtEnabled = tensorRtEnabled ?? (() => true),
       adapter = NativeUpscaleAdapter(player.platform as NativePlayer);

  /// Shared by plain playback, shader presets and AnimeJaNai. Keep decoded
  /// frames on the GPU and avoid decoder reinitialization when changing modes.
  static const hardwareDecoder = 'd3d11va';

  /// The shim configuration the filter must be given. The pinned filter only
  /// loads its inference shim when `conf` (or `engine`) is set; without it the
  /// filter stays a plain GPU copy. The name is resolved next to the installed
  /// shim, so no Windows path enters the filter's `:`-separated option syntax.
  static const janaiConfig = 'animejanai.conf';

  final Player player;
  final VideoController video;
  final NativeUpscaleAdapter adapter;
  final bool Function() tensorRtEnabled;
  final PlaybackTensorRtResources tensorRtResources;
  static int _sequence = 0;
  final String _identity =
      '$pid-${DateTime.now().microsecondsSinceEpoch}-'
      '${_sequence++}';
  File? _config;
  File? _status;
  int _configRevision = 0;
  final List<File> _files = [];

  Future<String> _janaiConfiguration() async {
    if (!tensorRtEnabled() || !tensorRtResources.canEnable) {
      throw StateError('AI 实时超分需要 NVIDIA 显卡，并先配置 TensorRT');
    }
    var directory = Directory(
      path.join(
        (await getApplicationSupportDirectory()).path,
        'playback-janai',
      ),
    );
    await directory.create(recursive: true);
    var bundled = File(
      path.join(path.dirname(Platform.resolvedExecutable), janaiConfig),
    );
    var text = await bundled.readAsString();
    // Make the bundle's relative paths absolute before moving its configuration
    // to writable app data. Keep models and runtime immutable in the bundle.
    text = text
        .split('\n')
        .map((line) {
          for (var key in ['runtime_dir', 'model_dir']) {
            if (line.startsWith('$key=')) {
              var value = line.substring(key.length + 1).trim();
              var absolute = path.normalize(
                path.join(bundled.parent.path, value),
              );
              return '$key=$absolute';
            }
          }
          return line;
        })
        .where(
          (line) =>
              !RegExp(r'^\s*(backend|trt_dir|engine_cache)\s*=').hasMatch(line),
        )
        .join('\n');
    var revision = ++_configRevision;
    var config = _config = File(
      path.join(directory.path, '$_identity-$revision.conf'),
    );
    var status = _status = File(
      path.join(directory.path, '$_identity-$revision.stats'),
    );
    _files.addAll([config, status]);
    await config.writeAsString(
      '$text\nbackend=tensorrt\n'
      'trt_dir=${tensorRtResources.runtimeDirectory}\n'
      'engine_cache=${tensorRtResources.engineDirectory}\n'
      'stats=${status.path}\n',
    );
    // mpv's fixed-length quoting protects Windows colons, commas, spaces and
    // Chinese paths in the filter option grammar; lengths are UTF-8 bytes.
    return '%${utf8.encode(config.path).length}%${config.path}';
  }

  @override
  Future<void> command(List<String> arguments) => adapter.command(arguments);

  @override
  Future<Object?> read(String property) => adapter.read(property);

  @override
  Future<void> shaders(List<String> paths) =>
      adapter.setStringList('glsl-shaders', paths);

  /// Only change the filter chain. The decoder stays on the shared GPU path;
  /// mpv refreshes a paused frame when vf changes, without an extra seek here.
  @override
  Future<void> janai(int? slot) async {
    if (slot == null) {
      // Capture the terminal build log before mpv releases the old filter.
      try {
        var previous = await janaiStatus();
        if (previous?.phase != 'failed') tensorRtResources.observe(null);
      } on FileSystemException {
        tensorRtResources.observe(null);
      } on FormatException {
        tensorRtResources.observe(null);
      }
    } else {
      tensorRtResources.beginBuild();
    }
    // The config path is what makes the pinned filter load the shim at all, so
    // it is part of the chain string rather than a separate option. This is the
    // only place that builds the chain; verification reads it back from mpv.
    var filter = slot == null
        ? null
        : '@${PlaybackUpscaleBackend.janaiFilterLabel}:'
              'animejanai=slot=$slot:conf=${await _janaiConfiguration()}';
    await adapter.setString('vf', filter ?? '');
    for (var file in _files.toList()) {
      if (slot != null && (file == _config || file == _status)) continue;
      if (await file.exists()) await file.delete();
      _files.remove(file);
    }
    if (slot == null) _config = _status = null;
  }

  @override
  Future<PlaybackJanaiStatus?> janaiStatus() async {
    var file = _status;
    if (file == null || !await file.exists()) return null;
    if (await file.length() > 16384) {
      throw const FormatException('AI 超分状态文件超出大小限制');
    }
    var text = await file.readAsString();
    if (file != _status) return null;
    var status = PlaybackJanaiStatus.parse(text);
    if (status.buildLog.isNotEmpty &&
        path.isWithin(
          tensorRtResources.engineDirectory,
          path.normalize(status.buildLog),
        ) &&
        RegExp(
          r'^[a-f0-9]{64}\.engine\.part-\d+-\d+\.log$',
        ).hasMatch(path.basename(status.buildLog))) {
      var log = File(status.buildLog);
      try {
        if (await log.exists()) {
          status = status.withBuildLines(await readPlaybackBuildLog(log));
        }
      } on FileSystemException {
        // A log can be rotated/pruned between exists() and open(). Do not turn
        // a diagnostic read failure into failed inference or clear old output.
      }
    }
    if (file != _status) return null;
    tensorRtResources.observe(status);
    return status;
  }

  /// Read mpv's MPV_FORMAT_NODE array of filter maps without string matching.
  @override
  Future<List<Map<Object?, Object?>>> filterList() async {
    var value = await adapter.read('vf');
    if (value is List) {
      var entries = <Map<Object?, Object?>>[];
      for (var entry in value) {
        if (entry is Map) {
          var params = entry['params'];
          entries.add({
            'name': entry['name'],
            if (entry['label'] != null) 'label': entry['label'],
            if (entry['enabled'] != null) 'enabled': entry['enabled'],
            if (params is Map) 'params': params,
          });
        } else {
          throw StateError('滤镜链路包含无法识别的节点');
        }
      }
      return entries;
    }
    throw StateError('滤镜链路返回了无法识别的结果：${value.runtimeType}');
  }

  @override
  Future<void> resize(PlaybackPixels? size) =>
      video.setSize(width: size?.width, height: size?.height);

  @override
  void close() => adapter.close();
}
