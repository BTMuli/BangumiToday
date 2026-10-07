// Package imports:
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// Project imports:
import '../../models/playback/playback_upscale.dart';
import 'native_upscale_adapter.dart';
import 'playback_upscaler.dart';

class NativePlaybackUpscaleBackend implements PlaybackUpscaleBackend {
  NativePlaybackUpscaleBackend(this.player, this.video)
    : adapter = NativeUpscaleAdapter(player.platform as NativePlayer);

  /// Decoder used while the AnimeJaNai filter is installed: the clip and the
  /// filter share one D3D11 device instead of copying frames back to memory.
  static const janaiDecoder = 'd3d11va';

  /// Decoder used for plain playback and shader presets, matching the ANGLE
  /// texture output that media_kit_video expects.
  static const plainDecoder = 'd3d11va-copy';

  /// The shim configuration the filter must be given. The pinned filter only
  /// loads its inference shim when `conf` (or `engine`) is set; without it the
  /// filter stays a plain GPU copy. The name is resolved next to the installed
  /// shim, so no Windows path enters the filter's `:`-separated option syntax.
  static const janaiConfig = 'animejanai.conf';

  final Player player;
  final VideoController video;
  final NativeUpscaleAdapter adapter;

  @override
  Future<void> command(List<String> arguments) => adapter.command(arguments);

  @override
  Future<Object?> read(String property) => adapter.read(property);

  @override
  Future<void> shaders(List<String> paths) =>
      adapter.setStringList('glsl-shaders', paths);

  /// Enable texture decoding before installing the filter. Clear the filter
  /// before returning to copy-back decoding during recovery.
  @override
  Future<void> janai(int? slot) async {
    // The config path is what makes the pinned filter load the shim at all, so
    // it is part of the chain string rather than a separate option. This is the
    // only place that builds the chain; verification reads it back from mpv.
    var filter = slot == null
        ? null
        : 'animejanai=slot=$slot:conf=$janaiConfig';
    if (slot == null) await adapter.setString('vf', '');
    var decoder = slot == null ? plainDecoder : janaiDecoder;
    if (await adapter.read('hwdec') != decoder) {
      await adapter.setString('hwdec', decoder);
    }
    if (slot != null) await adapter.setString('vf', filter!);
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
  Future<void> redraw() async {
    if (!player.state.playing && !player.state.completed) {
      // A zero relative seek redraws the paused frame without restoring a
      // captured absolute position over a concurrent user seek.
      await adapter.command(['seek', '0', 'relative+exact']);
    }
  }

  @override
  void close() => adapter.close();
}
