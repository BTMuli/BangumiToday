// Dart imports:
import 'dart:io';

// Package imports:
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as path;

// Project imports:
import 'playback_assets.dart';

/// Shares the bundled UI fonts with mpv without installing system fonts.
abstract final class PlaybackSubtitles {
  static const fontFiles = [
    'SarasaMonoSC-Regular.ttf',
    'SarasaMonoTC-Regular.ttf',
    'SarasaMonoJ-Regular.ttf',
  ];

  static String fontsDirectory({
    required String executable,
    required String operatingSystem,
  }) {
    var paths = path.Context(
      style: operatingSystem == 'windows'
          ? path.Style.windows
          : path.Style.posix,
    );
    return paths.join(
      PlaybackAssets.directory(
        executable: executable,
        operatingSystem: operatingSystem,
      ),
      'fonts',
    );
  }

  /// Configure before the first media load, when libass reads its font folder.
  static Future<void> configure(Player player) async {
    var directory = fontsDirectory(
      executable: Platform.resolvedExecutable,
      operatingSystem: Platform.operatingSystem,
    );
    for (var name in fontFiles) {
      var file = File(path.join(directory, name));
      if (!await file.exists()) {
        throw FileSystemException('应用字幕字体缺失，请重新构建或安装应用', file.path);
      }
    }

    var native = player.platform as NativePlayer;
    var options = {
      'sub-fonts-dir': directory,
      // libass tries the ASS font first, then this default family if missing.
      // Use the font's actual family name, rather than Flutter's SMonoSC alias.
      'sub-font': 'Sarasa Mono SC',
      'embeddedfonts': 'yes',
      'sub-ass-override': 'no',
      'blend-subtitles': 'no',
      // The store selects by language/title once tracks become available.
      'sid': 'no',
      'secondary-sid': 'no',
      // These defaults style unstyled text, preserving ASS/SSA script styles.
      'sub-color': '#FFFFFF',
      'sub-border-color': '#202020',
      'sub-border-size': '2',
      'sub-back-color': '#00000000',
      'sub-shadow-offset': '0',
    };
    for (var option in options.entries) {
      await native.setProperty(option.key, option.value);
    }
  }
}
