// Project imports:
import 'playback_item.dart';

/// Immutable EOF evidence. A later playlist change cannot change its file.
class PlaybackCompletion {
  const PlaybackCompletion({
    required this.sessionId,
    required this.item,
    required this.positionMs,
    required this.durationMs,
  });

  final String sessionId;
  final PlaybackItem item;
  final int positionMs;
  final int durationMs;

  String get eventId => '$sessionId:eof';
  String get fileKey => item.key;
  String get reason => 'eof';

  PlaybackItem get historyItem => PlaybackItem(
    filePath: item.filePath,
    title: item.title,
    subject: item.subject,
    positionMs: durationMs,
    durationMs: durationMs,
    completed: true,
    updatedAt: DateTime.now().millisecondsSinceEpoch,
  );
}

/// Session identity and EOF deduplication, independent of mpv and the UI.
class PlaybackSession {
  PlaybackSession()
    : _generation = DateTime.now().microsecondsSinceEpoch.toString();

  final String _generation;
  int _sequence = 0;
  PlaybackItem? _item;
  bool _finished = false;
  bool _closed = false;

  String get id => '$_generation:$_sequence';

  void begin(PlaybackItem item) {
    if (_closed) return;
    _sequence++;
    _item = item;
    _finished = false;
  }

  PlaybackCompletion? finish({
    required Duration position,
    required Duration duration,
  }) {
    var item = _item;
    if (_closed || _finished || item == null || duration <= Duration.zero) {
      return null;
    }
    _finished = true;
    return PlaybackCompletion(
      sessionId: id,
      item: item,
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
    );
  }

  void clear() {
    _sequence++;
    _item = null;
  }

  void close() {
    _closed = true;
    clear();
  }
}
