/// Minimal immutable data needed to map a local file to a Bangumi episode.
class EpisodeMarkEpisode {
  const EpisodeMarkEpisode({
    required this.id,
    required this.type,
    required this.sort,
    required this.name,
    this.withinSubject,
  });

  final int id;
  final int type;
  final double sort;
  final String name;
  final double? withinSubject;
}

class EpisodeMarkPage {
  const EpisodeMarkPage({
    required this.total,
    required this.offset,
    required this.episodes,
  });

  final int total;
  final int offset;
  final List<EpisodeMarkEpisode> episodes;
}

class EpisodeMarkFailure implements Exception {
  const EpisodeMarkFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// API/storage adapter; the resolver does not depend on Flutter or credentials.
abstract interface class EpisodeMarkGateway {
  Future<EpisodeMarkPage> episodes(int subject, int offset);
  Future<bool> isDone(int episode);
  Future<void> markDone(int episode, {required bool Function() authScope});
  Future<void> invalidateSubject(int subject);
}
