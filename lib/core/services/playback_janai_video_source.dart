typedef PlaybackJanaiVideoParameters = ({
  String? trackId,
  int? width,
  int? height,
  double? fps,
});

/// Reads the selected mpv track, independently of media_kit's auto/no entries.
/// Decoder dimensions precede the fixed 2x filter's output dimensions.
class PlaybackJanaiVideoSource {
  PlaybackJanaiVideoSource({required this.read, required this.onChanged});

  final Future<String> Function(String) read;
  final void Function() onChanged;
  PlaybackJanaiVideoParameters? parameters;
  bool _active = false;
  bool _closed = false;
  int _revision = 0;

  static const properties = [
    'current-tracks/video/id',
    'current-tracks/video/demux-w',
    'current-tracks/video/demux-h',
    'current-tracks/video/demux-fps',
    'video-dec-params/w',
    'video-dec-params/h',
  ];

  static PlaybackJanaiVideoParameters? parse(Map<String, String> properties) {
    var trackId = properties['current-tracks/video/id'];
    if ((int.tryParse(trackId ?? '') ?? 0) <= 0) return null;
    int? dimension(String name) {
      var value = int.tryParse(properties[name] ?? '');
      return value != null && value > 0 ? value : null;
    }

    var width = dimension('video-dec-params/w');
    var height = dimension('video-dec-params/h');
    if (width == null || height == null) {
      width = dimension('current-tracks/video/demux-w');
      height = dimension('current-tracks/video/demux-h');
    }
    var fps = double.tryParse(
      properties['current-tracks/video/demux-fps'] ?? '',
    );
    return (
      trackId: trackId,
      width: width,
      height: height,
      fps: fps != null && fps.isFinite && fps > 0 ? fps : null,
    );
  }

  void reset({bool active = false}) {
    _revision++;
    _active = active;
    if (parameters == null) return;
    parameters = null;
    onChanged();
  }

  Future<void> refresh() async {
    if (!_active || _closed) return;
    var revision = ++_revision;
    try {
      var values = await Future.wait(properties.map(read));
      if (_closed || !_active || revision != _revision) return;
      var next = parse(Map.fromIterables(properties, values));
      if (parameters == next) return;
      parameters = next;
      onChanged();
    } catch (_) {
      // Missing source metadata cannot prevent playback. Later parameter or
      // track events retry through the same bounded asynchronous reader.
    }
  }

  void close() {
    _closed = true;
    reset();
  }
}
