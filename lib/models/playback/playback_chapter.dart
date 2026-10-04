class PlaybackChapter {
  const PlaybackChapter({required this.title, required this.start});

  final String title;
  final Duration start;

  static PlaybackChapter? parse({
    required int index,
    required String time,
    required String title,
  }) {
    var seconds = double.tryParse(time);
    if (seconds == null || !seconds.isFinite || seconds < 0) return null;
    return PlaybackChapter(
      title: title.trim().isEmpty ? '章节 ${index + 1}' : title.trim(),
      start: Duration(
        microseconds: (seconds * Duration.microsecondsPerSecond).round(),
      ),
    );
  }
}

List<PlaybackChapter> normalizePlaybackChapters(
  Iterable<PlaybackChapter> chapters,
) {
  var sorted = chapters.toList()..sort((a, b) => a.start.compareTo(b.start));
  var starts = <Duration>{};
  return List.unmodifiable([
    for (var chapter in sorted)
      if (starts.add(chapter.start)) chapter,
  ]);
}

PlaybackChapter? playbackChapterAt(
  List<PlaybackChapter> chapters,
  Duration position,
) {
  for (var chapter in chapters.reversed) {
    if (chapter.start <= position) return chapter;
  }
  return null;
}

/// Previous restarts the current chapter after 3s, otherwise goes back one.
PlaybackChapter? adjacentPlaybackChapter(
  List<PlaybackChapter> chapters,
  Duration position, {
  required bool next,
}) {
  if (next) {
    for (var chapter in chapters) {
      if (chapter.start > position) return chapter;
    }
  } else {
    var current = playbackChapterAt(chapters, position);
    if (current == null) return null;
    if (position - current.start >= const Duration(seconds: 3)) return current;
    var index = chapters.indexOf(current);
    if (index > 0) return chapters[index - 1];
  }
  return null;
}
