// Dart imports:
import 'dart:io';

// Package imports:
import 'package:media_kit/media_kit.dart';

// Project imports:
import '../../models/playback/playback_hires.dart';
import 'native_upscale_adapter.dart';
import 'playback_audio_metadata.dart';

abstract final class PlaybackAudio {
  static const settingKey = 'playbackHiResEnabled';
  static const exclusiveSettingKey = 'playbackAudioExclusiveEnabled';
  static bool get supported => Platform.isWindows || Platform.isMacOS;

  static Future<({PlaybackAudioSource? source, PlaybackAudioOutput? output})>
  read(
    Player player, {
    required String filePath,
    required PlaybackAudioMetadata metadata,
    PlaybackWasapiFormat? deviceFormat,
  }) async {
    var adapter = NativeUpscaleAdapter(player.platform as NativePlayer);
    Future<Map<Object?, Object?>> map(String property) async {
      try {
        var value = await adapter.read(property);
        return value is Map ? value.cast<Object?, Object?>() : const {};
      } on NativeUpscaleException catch (error) {
        // No selected audio or a device still reopening has no params yet.
        if (error.code == -10) return const {};
        rethrow;
      }
    }

    int number(Object? value) => value is num ? value.toInt() : 0;
    try {
      var track = await map('current-tracks/audio');
      var decoded = await map('audio-params');
      var actual = await map('audio-out-params');
      var driver = actual.isEmpty ? '' : '${await adapter.read('current-ao')}';
      var codec = '${track['codec'] ?? ''}';
      var encodedBits = track.isEmpty
          ? null
          : await metadata.bitDepth(
              track['external-filename'] as String? ?? filePath,
              codec: codec,
              track: (track['src-id'] as num?)?.toInt(),
              streamIndex: (track['ff-index'] as num?)?.toInt(),
            );
      var deviceMatches =
          driver == 'wasapi' &&
          deviceFormat != null &&
          deviceFormat.sampleRate == number(actual['samplerate']) &&
          deviceFormat.format == actual['format'];
      return (
        source: track.isEmpty || decoded.isEmpty
            ? null
            : PlaybackAudioSource(
                id: '${track['id']}',
                codec: codec,
                sampleRate: number(decoded['samplerate']),
                format: '${decoded['format'] ?? ''}',
                channels: number(decoded['channel-count']),
                encodedBits: encodedBits,
              ),
        output: actual.isEmpty
            ? null
            : PlaybackAudioOutput(
                sampleRate: number(actual['samplerate']),
                format: '${actual['format'] ?? ''}',
                channels: number(actual['channel-count']),
                driver: driver,
                devicePrecision: deviceMatches ? deviceFormat.precision : null,
                exclusive: deviceMatches ? deviceFormat.exclusive : null,
              ),
      );
    } finally {
      await adapter.close();
    }
  }

  /// Let the AO negotiate the decoded rate/precision with the device. Shared
  /// WASAPI uses the Windows mix format; exclusive mode can use the source
  /// format directly. Reopen between files so an earlier format is not
  /// retained.
  static Future<void> apply(Player player, bool exclusive) async {
    var adapter = NativeUpscaleAdapter(player.platform as NativePlayer);
    try {
      for (var option in {
        'audio-samplerate': '0',
        'gapless-audio': exclusive ? 'no' : 'weak',
        if (Platform.isWindows || Platform.isMacOS)
          'audio-exclusive': exclusive ? 'yes' : 'no',
      }.entries) {
        await adapter.command(['set', option.key, option.value]);
      }
    } finally {
      await adapter.close();
    }
  }

  /// The pinned mpv also uses this command when WASAPI has no live AO to
  /// receive device notifications. Reapplying unchanged options does not
  /// restart a missing output.
  static Future<void> reopenOutput(Player player) async {
    var adapter = NativeUpscaleAdapter(player.platform as NativePlayer);
    try {
      await adapter.command(['ao-reload']);
    } finally {
      await adapter.close();
    }
  }
}
