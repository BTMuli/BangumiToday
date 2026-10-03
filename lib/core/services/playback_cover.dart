// Project imports:
import '../../domain/repositories/bangumi_repository.dart';
import '../../models/bangumi/bangumi_model.dart';

/// Resolves a Bangumi subject id to its cover image URL and name, cached in
/// memory.
///
/// Only the resolved fields are retained here; the image bytes are cached
/// separately by `CachedNetworkImage`. A failed lookup is recorded as `null`
/// so it is not repeated.
class PlaybackCover {
  PlaybackCover(this._repository);

  final BTBangumiRepository _repository;
  final Map<int, BangumiSubject?> _subjects = {};
  final Set<int> _inFlight = {};

  /// Whether [subject] has already been resolved (with data or a miss).
  bool contains(int subject) => _subjects.containsKey(subject);

  /// The cached cover URL for [subject], or `null` when it is not yet
  /// resolved or the subject has no usable cover.
  String? coverOf(int subject) {
    var data = _subjects[subject];
    if (data == null) return null;
    return _firstNonEmpty([
      data.images.large,
      data.images.medium,
      data.images.common,
      data.images.grid,
    ]);
  }

  /// The cached display name for [subject], or `null` when unknown.
  String? nameOf(int subject) {
    var data = _subjects[subject];
    if (data == null) return null;
    return data.nameCn.isNotEmpty ? data.nameCn : data.name;
  }

  /// Resolves and caches the subject detail for [subject].
  ///
  /// Concurrent requests for the same subject share a single lookup. Returns
  /// the cached cover URL (or `null` when there is no cover).
  Future<String?> resolve(int subject) async {
    if (_subjects.containsKey(subject)) return coverOf(subject);
    if (!_inFlight.add(subject)) return null;
    try {
      BangumiSubject? data;
      try {
        var response = await _repository.getSubjectDetail(subject.toString());
        data = response.code == 0 ? response.data : null;
      } catch (_) {
        data = null;
      }
      _subjects[subject] = data;
      return coverOf(subject);
    } finally {
      _inFlight.remove(subject);
    }
  }

  static String? _firstNonEmpty(List<String> values) {
    for (var value in values) {
      if (value.isNotEmpty) return value;
    }
    return null;
  }
}
