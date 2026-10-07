// Project imports:
import 'playback_item.dart';

/// A durable chapter association, or an explicit exclusion from matching.
class PlaybackEpisodeLink {
  const PlaybackEpisodeLink({
    required this.filePath,
    required this.subject,
    required this.episode,
  });

  final String filePath;
  final int subject;

  /// Null means this file does not correspond to a chapter of the subject.
  final int? episode;

  bool get excluded => episode == null;

  String get key => PlaybackItem.pathKey(filePath);

  factory PlaybackEpisodeLink.fromJson(Map<String, dynamic> value) =>
      PlaybackEpisodeLink(
        filePath: value['filePath'] as String,
        subject: value['subject'] as int,
        episode: value['episode'] as int?,
      );

  Map<String, Object?> toJson() => {
    'filePath': filePath,
    'subject': subject,
    'episode': episode,
  };
}
