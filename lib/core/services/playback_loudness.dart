// Dart imports:
import 'dart:ffi';

// Package imports:
import 'package:ffi/ffi.dart';
import 'package:media_kit/media_kit.dart';

// Project imports:
import '../errors/playback_unavailable.dart';

/// A labelled filter keeps loudness processing independent of other audio FX.
abstract final class PlaybackLoudness {
  static const settingKey = 'playbackLoudnessEnabled';
  static const label = 'bangumi_loudness';

  // Peak normalization avoids pulling loud scenes down to a fixed RMS target.
  // Smooth a 3.1-second neighbourhood and cap amplification at 3x. Alternative
  // boundaries preserve gain after seeks instead of fading back in from 1x.
  // https://ffmpeg.org/ffmpeg-filters.html#dynaudnorm
  static const filter =
      '@$label:lavfi=[dynaudnorm=f=100:g=31:p=0.95:m=3:r=0:n=1:b=1:t=0]';

  static bool parse(String? value) => value != 'false';

  static Future<void> apply(Player player, bool enabled) async {
    var native = player.platform;
    if (native is! NativePlayer) {
      throw const PlaybackUnavailable('当前播放器不支持响度均衡');
    }
    // Use the existing disposal lock and check the actual command result:
    // NativePlayer.command reports native failures only through its log stream.
    await NativePlayer.lock.synchronized(() async {
      if (native.disposed) throw StateError('播放器已经关闭');
      await native.waitForPlayerInitialization;
      if (native.disposed || native.ctx == nullptr) {
        throw StateError('播放器已经关闭');
      }
      var arguments = [
        'af',
        enabled ? 'add' : 'remove',
        enabled ? filter : '@$label',
      ];
      var strings = <Pointer<Utf8>>[];
      var pointers = calloc<Pointer<Int8>>(arguments.length + 1);
      try {
        for (var index = 0; index < arguments.length; index++) {
          var value = arguments[index].toNativeUtf8();
          strings.add(value);
          pointers[index] = value.cast();
        }
        var result = native.mpv.mpv_command(native.ctx, pointers);
        if (result < 0) {
          var message = native.mpv.mpv_error_string(result);
          var detail = message == nullptr
              ? '$result'
              : message.cast<Utf8>().toDartString();
          throw PlaybackUnavailable('无法切换响度均衡：$detail');
        }
      } finally {
        for (var value in strings) {
          calloc.free(value);
        }
        calloc.free(pointers);
      }
    });
  }
}
