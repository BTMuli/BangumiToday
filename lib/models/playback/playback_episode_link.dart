// Project imports:
import 'playback_item.dart';

/// A durable, account-independent association between a file and a chapter.
class PlaybackEpisodeLink {
  const PlaybackEpisodeLink({
    required this.filePath,
    required this.subject,
    required this.episode,
  });

  final String filePath;
  final int subject;
  final int episode;

  String get key => PlaybackItem.pathKey(filePath);

  factory PlaybackEpisodeLink.fromJson(Map<String, dynamic> value) =>
      PlaybackEpisodeLink(
        filePath: value['filePath'] as String,
        subject: value['subject'] as int,
        episode: value['episode'] as int,
      );

  Map<String, Object> toJson() => {
    'filePath': filePath,
    'subject': subject,
    'episode': episode,
  };
}
