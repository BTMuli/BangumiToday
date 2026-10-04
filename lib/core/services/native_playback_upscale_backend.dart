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

  final Player player;
  final VideoController video;
  final NativeUpscaleAdapter adapter;

  @override
  Future<void> command(List<String> arguments) => adapter.command(arguments);

  @override
  Future<Object?> read(String property) => adapter.read(property);

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
