// Project imports:
import 'playback_upscale.dart';

enum PlaybackExportResolution {
  qhd('2K', 2560, 1440),
  uhd('4K', 3840, 2160);

  const PlaybackExportResolution(this.label, this.width, this.height);

  final String label;
  final int width;
  final int height;

  static PlaybackExportResolution forDisplay({
    required double width,
    required double height,
  }) {
    var (longEdge, shortEdge) = width >= height
        ? (width, height)
        : (height, width);
    return longEdge >= uhd.width && shortEdge >= uhd.height ? uhd : qhd;
  }
}

/// Fits the source's display aspect ratio within the selected resolution.
PlaybackPixels playbackExportSize(
  PlaybackVideoSource source,
  PlaybackUpscaleMode mode,
  PlaybackExportResolution resolution,
) {
  if (mode == PlaybackUpscaleMode.off) {
    throw ArgumentError('请选择超分档位');
  }
  if (source.width <= 0 || source.height <= 0) {
    throw StateError('等待视频参数');
  }
  var unavailable = playbackUpscaleSourceUnavailable(source, mode);
  if (unavailable != null) throw StateError(unavailable);

  var (maxWidth, maxHeight) = source.width >= source.height
      ? (resolution.width, resolution.height)
      : (resolution.height, resolution.width);
  var fitsWidth = maxWidth * source.height <= maxHeight * source.width;
  var width = fitsWidth ? maxWidth : maxHeight * source.width ~/ source.height;
  var height = fitsWidth ? maxWidth * source.height ~/ source.width : maxHeight;
  // The encoder uses 4:2:0 chroma subsampling.
  width -= width % 2;
  height -= height % 2;
  if (width <= source.width || height <= source.height) {
    throw StateError('${resolution.label} 导出尺寸需大于源视频');
  }
  return (width: width, height: height);
}

enum PlaybackExportFormat {
  mp4('MP4', ['mp4', 'm4v'], 'mp4'),
  mkv('MKV', ['mkv'], 'matroska'),
  mov('MOV', ['mov'], 'mov'),
  webm('WebM', ['webm'], 'webm'),
  avi('AVI', ['avi'], 'avi'),
  ts('MPEG-TS', ['ts'], 'mpegts'),
  flv('FLV', ['flv'], 'flv');

  const PlaybackExportFormat(this.label, this.extensions, this.muxer);
  final String label;
  final List<String> extensions;
  final String muxer;

  String get codecs => switch (this) {
    webm => 'VP9 + Opus',
    avi => 'H.264 + MP3',
    _ => 'H.264 + AAC',
  };

  static PlaybackExportFormat? fromExtension(String extension) {
    var value = extension.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    return values
        .where((format) => format.extensions.contains(value))
        .firstOrNull;
  }
}
