// Package imports:
import 'package:media_kit/media_kit.dart';

// Project imports:
import '../../models/playback/playback_chapter.dart';

/// One observer per Player, shared by the windowed and fullscreen controls.
class PlaybackChapters {
  PlaybackChapters(this._native, {required this.onChanged});

  final NativePlayer _native;
  final void Function() onChanged;
  List<PlaybackChapter> chapters = const [];
  int _revision = 0;
  bool _active = false;
  bool _closed = false;

  Future<void> initialize() =>
      _native.observeProperty('chapter-list', (_) => refresh());

  void reset({bool active = false}) {
    _revision++;
    _active = active;
    chapters = const [];
    onChanged();
  }

  Future<void> refresh() async {
    if (!_active || _closed) return;
    var revision = ++_revision;
    bool current() => !_closed && _active && _revision == revision;
    var count = int.tryParse(await _native.getProperty('chapter-list/count'));
    if (!current()) return;
    var result = <PlaybackChapter>[];
    for (var index = 0; index < (count ?? 0); index++) {
      var time = await _native.getProperty('chapter-list/$index/time');
      if (!current()) return;
      var title = await _native.getProperty('chapter-list/$index/title');
      if (!current()) return;
      var chapter = PlaybackChapter.parse(
        index: index,
        time: time,
        title: title,
      );
      if (chapter != null) result.add(chapter);
    }
    if (!current()) return;
    chapters = normalizePlaybackChapters(result);
    onChanged();
  }

  // Player disposal removes its observers. Invalidate pending reads first.
  void close() {
    _closed = true;
    reset();
  }
}
