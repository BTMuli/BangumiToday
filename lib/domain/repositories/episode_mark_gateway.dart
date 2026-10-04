/// Minimal immutable data needed to map a local file to a Bangumi episode.
class EpisodeMarkEpisode {
  const EpisodeMarkEpisode({
    required this.id,
    required this.type,
    required this.sort,
    required this.name,
    this.withinSubject,
    this.done,
  });

  final int id;
  final int type;

  /// Broadcast numbering; sequels may continue from the previous season.
  final double sort;
  final String name;

  /// Bangumi ep: numbering within this subject, starting at 1.
  final double? withinSubject;
  final bool? done;

  EpisodeMarkEpisode withDone(bool value) => EpisodeMarkEpisode(
    id: id,
    type: type,
    sort: sort,
    name: name,
    withinSubject: withinSubject,
    done: value,
  );
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
  Future<EpisodeMarkPage> progress(int subject, int offset);
  Future<bool> isDone(int episode);
  Future<void> markDone(int episode, {required bool Function() authScope});
  Future<void> invalidateSubject(int subject);
}
