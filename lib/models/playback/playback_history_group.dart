// Project imports:
import 'playback_item.dart';

/// One visible history entry per Bangumi subject. Per-file progress remains
/// intact for resuming individual episodes and for existing saved records.
class PlaybackHistoryGroup {
  PlaybackHistoryGroup(this.key, Iterable<PlaybackItem> items)
    : items = List.unmodifiable(items);

  final String key;
  final List<PlaybackItem> items;

  PlaybackItem get latest => items.first;
  int? get subject => (latest.subject ?? 0) > 0 ? latest.subject : null;

  static String keyFor(PlaybackItem item) =>
      (item.subject ?? 0) > 0 ? 'subject:${item.subject}' : 'file:${item.key}';
}

List<PlaybackHistoryGroup> groupPlaybackHistory(
  Iterable<PlaybackItem> history,
) {
  var grouped = <String, Map<String, PlaybackItem>>{};
  for (var item in history) {
    var items = grouped.putIfAbsent(
      PlaybackHistoryGroup.keyFor(item),
      () => {},
    );
    var previous = items[item.key];
    if (previous == null || previous.updatedAt <= item.updatedAt) {
      items[item.key] = item;
    }
  }
  int recentFirst(PlaybackItem a, PlaybackItem b) {
    var order = b.updatedAt.compareTo(a.updatedAt);
    return order == 0 ? a.key.compareTo(b.key) : order;
  }

  var groups = [
    for (var entry in grouped.entries)
      PlaybackHistoryGroup(
        entry.key,
        entry.value.values.toList()..sort(recentFirst),
      ),
  ]..sort((a, b) => recentFirst(a.latest, b.latest));
  return List.unmodifiable(groups);
}
