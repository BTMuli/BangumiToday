import 'playback_item.dart';

/// The account's chapter progress, separate from local playback completion.
class EpisodeMarkState {
  const EpisodeMarkState({
    this.account,
    this.marked = const {},
    this.checked = const {},
    this.loading = const {},
  });

  final String? account;
  final Set<String> marked;
  final Set<String> checked;
  final Set<String> loading;

  static String itemKey(PlaybackItem item) => '${item.subject}:${item.key}';
}
