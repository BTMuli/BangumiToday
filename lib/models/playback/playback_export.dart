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
