// Dart imports:
import 'dart:async';

// Project imports:
import '../../domain/repositories/episode_mark_gateway.dart';
import '../../domain/repositories/playback_episode_links.dart';
import '../../models/playback/episode_mark_state.dart';
import '../../models/playback/playback_episode_link.dart';
import '../../models/playback/playback_item.dart';
import '../utils/episode_num_extractor.dart';

class EpisodeMarkCandidate {
  const EpisodeMarkCandidate({
    required this.item,
    required this.account,
    required this.episode,
    required this.number,
    this.linkedEpisode,
  });

  final PlaybackItem item;
  final String account;
  final EpisodeMarkEpisode episode;
  final double number;
  final int? linkedEpisode;

  int get subject => item.subject!;
}

class EpisodeMarkResolution {
  const EpisodeMarkResolution({
    this.candidate,
    this.message,
    this.retryable = false,
    this.alreadyDone = false,
  });

  final EpisodeMarkCandidate? candidate;
  final String? message;
  final bool retryable;
  final bool alreadyDone;
}

enum EpisodeMarkWriteStatus { marked, alreadyDone, failed, expired }

class EpisodeMarkWriteResult {
  const EpisodeMarkWriteResult(this.status, {this.message});

  final EpisodeMarkWriteStatus status;
  final String? message;
}

class EpisodeMarkRefresh {
  const EpisodeMarkRefresh(this.account, this.subject, this.episode);

  final String account;
  final int subject;
  final int episode;
}

/// Network work never joins the playback operation queue. Each explicit row
/// action resolves its own file and writes done without a confirmation dialog.
class EpisodeMarkService {
  EpisodeMarkService({
    required this.gateway,
    required this.accountSession,
    required this.links,
  }) {
    _linkSubscription = links.watchAll().listen(
      (value) {
        _links = value;
        _notifyProgress();
      },
      onError: (Object _) {
        // Explicit actions reread storage and report failures to the caller.
      },
    );
  }

  final EpisodeMarkGateway gateway;
  final String? Function() accountSession;
  final PlaybackEpisodeLinks links;
  late final StreamSubscription<Map<String, PlaybackEpisodeLink>>
  _linkSubscription;
  Map<String, PlaybackEpisodeLink> _links = {};
  final _pages = <String, Future<List<EpisodeMarkEpisode>>>{};
  final _writes = <String, Future<EpisodeMarkWriteResult>>{};
  final _refreshes = StreamController<EpisodeMarkRefresh>.broadcast();
  final _progressChanges = StreamController<EpisodeMarkState>.broadcast();
  final _items = <String, PlaybackItem>{};
  final _progress = <int, Map<int, EpisodeMarkEpisode>>{};
  final _progressLoads = <int, Future<void>>{};
  final _loadedSubjects = <int>{};
  final _loadingSubjects = <int>{};
  final _episodeVersions = <int, Map<int, int>>{};
  int _progressVersion = 0;
  String? _progressAccount;
  bool _closed = false;

  Stream<EpisodeMarkRefresh> get refreshes => _refreshes.stream;
  Stream<EpisodeMarkState> get progressChanges => _progressChanges.stream;
  int get progressVersion => _progressVersion;

  bool _current(String account) => !_closed && accountSession() == account;

  /// Uses the same mapping for status and writes. Unnumbered files require
  /// a complete chapter list, rather than a partial progress observation.
  static EpisodeMarkEpisode? matchingEpisode(
    PlaybackItem item,
    Iterable<EpisodeMarkEpisode> episodes, {
    bool complete = true,
    int? episodeId,
  }) {
    if ((item.subject ?? 0) <= 0) return null;
    // Explicit links also support specials, fractional sorts and plain names.
    // A removed chapter must not silently fall back to filename inference.
    if (episodeId != null) {
      return episodes.where((episode) => episode.id == episodeId).singleOrNull;
    }
    var evidence = extractEpisodeNumber(item.filePath);
    return _matchingEpisode(evidence, episodes, complete: complete);
  }

  int? _linkedEpisode(PlaybackItem item) {
    var link = _links[item.key];
    return link?.subject == item.subject ? link?.episode : null;
  }

  bool _linkConflict(PlaybackItem item) {
    var link = _links[item.key];
    return link != null && link.subject != item.subject;
  }

  bool _excluded(PlaybackItem item) =>
      _links[item.key]?.subject == item.subject &&
      _links[item.key]?.excluded == true;

  static EpisodeMarkEpisode? _matchingEpisode(
    EpisodeNumberResult evidence,
    Iterable<EpisodeMarkEpisode> episodes, {
    bool complete = true,
  }) {
    if (evidence.kind != EpisodeNumberKind.single &&
        evidence.kind != EpisodeNumberKind.unknown) {
      return null;
    }
    var number = evidence.number;
    if (number != null && number != number.truncateToDouble()) {
      // Fractional broadcast numbers can belong to a main chapter or a recap
      // listed as a special. Never infer them from subject-relative numbering
      // or an incomplete list that could hide another chapter with this sort.
      if (!complete) return null;
      return episodes
          .where(
            (episode) =>
                episode.id > 0 &&
                (episode.type == 0 || episode.type == 1) &&
                episode.sort == number,
          )
          .singleOrNull;
    }
    var mainEpisodes = episodes.where((episode) => episode.type == 0).toList();
    var validEpisodes = mainEpisodes
        .where(
          (episode) =>
              episode.id > 0 &&
              episode.sort.isFinite &&
              episode.sort > 0 &&
              episode.sort == episode.sort.truncateToDouble(),
        )
        .toList();
    // Movies often have no filename episode marker. The associated subject
    // must have exactly one main chapter; never override an explicit number.
    if (evidence.kind == EpisodeNumberKind.unknown) {
      return complete && mainEpisodes.length == 1
          ? validEpisodes.singleOrNull
          : null;
    }
    // The associated subject already scopes the file to a season. S02E01
    // explicitly uses ep; ordinary release numbers can use either ep or sort.
    var localMatches = validEpisodes
        .where((episode) => episode.withinSubject == evidence.number)
        .toList();
    if (evidence.season != null && localMatches.isNotEmpty) {
      return localMatches.length == 1 ? localMatches.single : null;
    }
    var matches = validEpisodes
        .where(
          (episode) =>
              episode.sort == evidence.number ||
              episode.withinSubject == evidence.number,
        )
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  EpisodeMarkState get progressState {
    var checked = <String>{};
    var marked = <String>{};
    var loading = <String>{};
    for (var entry in _items.entries) {
      if (_linkConflict(entry.value) || _excluded(entry.value)) continue;
      var subject = entry.value.subject;
      if (_loadingSubjects.contains(subject)) loading.add(entry.key);
      var episode = matchingEpisode(
        entry.value,
        _progress[subject]?.values ?? const <EpisodeMarkEpisode>[],
        complete: _loadedSubjects.contains(subject),
        episodeId: _linkedEpisode(entry.value),
      );
      if (episode?.done == null) continue;
      checked.add(entry.key);
      if (episode!.done!) marked.add(entry.key);
    }
    return EpisodeMarkState(
      account: _progressAccount,
      checked: Set.unmodifiable(checked),
      marked: Set.unmodifiable(marked),
      loading: Set.unmodifiable(loading),
    );
  }

  void resetProgress() {
    _progressAccount = accountSession();
    _items.clear();
    _progress.clear();
    _progressLoads.clear();
    _loadedSubjects.clear();
    _loadingSubjects.clear();
    _episodeVersions.clear();
  }

  void _ensureProgressAccount() {
    if (_progressAccount != accountSession()) resetProgress();
  }

  void _notifyProgress() {
    if (!_closed) _progressChanges.add(progressState);
  }

  bool _hasProgress(int subject) =>
      _loadedSubjects.contains(subject) ||
      _items.values
          .where((item) => item.subject == subject)
          .every(
            (item) =>
                _linkConflict(item) ||
                _excluded(item) ||
                matchingEpisode(
                      item,
                      _progress[subject]?.values ??
                          const <EpisodeMarkEpisode>[],
                      complete: false,
                      episodeId: _linkedEpisode(item),
                    )?.done !=
                    null,
          );

  /// Fetch each subject once for the whole playlist, independently of playback.
  Future<void> syncItems(
    Iterable<PlaybackItem> items, {
    bool refresh = false,
  }) async {
    _ensureProgressAccount();
    var account = _progressAccount;
    if (_closed || account == null) return;
    var linked = await links.readAll();
    if (!_current(account)) return;
    _links = linked;
    _items.clear();
    for (var item in items) {
      if ((item.subject ?? 0) > 0) {
        _items[EpisodeMarkState.itemKey(item)] = item;
      }
    }
    _notifyProgress();
    await Future.wait([
      for (var subject in _items.values.map((item) => item.subject!).toSet())
        if (refresh || !_hasProgress(subject)) _loadProgress(subject, account),
    ]);
  }

  Future<void> _loadProgress(int subject, String account) {
    var pending = _progressLoads[subject];
    if (pending != null) return pending;
    var version = _progressVersion;
    _loadingSubjects.add(subject);
    _notifyProgress();
    late Future<void> future;
    future = () async {
      try {
        var episodes = await _allEpisodes(
          subject,
          account,
          readPage: gateway.progress,
        );
        if (!_current(account)) return;
        // A query started before a chapter edit must not undo that newer edit.
        var newer = {
          for (var entry in (_progress[subject] ?? {}).entries)
            if ((_episodeVersions[subject]?[entry.key] ?? 0) > version)
              entry.key: entry.value,
        };
        _progress[subject] = {
          for (var episode in episodes) episode.id: episode,
          ...newer,
        };
        _loadedSubjects.add(subject);
      } finally {
        if (_current(account) && identical(_progressLoads[subject], future)) {
          // This is the current future: waiting for it would await itself.
          unawaited(_progressLoads.remove(subject));
          _loadingSubjects.remove(subject);
          _notifyProgress();
        }
      }
    }();
    _progressLoads[subject] = future;
    return future;
  }

  /// Details-page reads/edits publish the same authoritative chapter data.
  void observeProgress(
    int subject,
    Iterable<EpisodeMarkEpisode> episodes, {
    required String? account,
    int? since,
  }) {
    if (account == null || !_current(account)) return;
    _ensureProgressAccount();
    var progress = _progress.putIfAbsent(subject, () => {});
    var versions = _episodeVersions.putIfAbsent(subject, () => {});
    for (var episode in episodes) {
      if (episode.id <= 0 || episode.done == null) continue;
      if (since != null && (versions[episode.id] ?? 0) > since) continue;
      progress[episode.id] = episode;
      versions[episode.id] = ++_progressVersion;
    }
    _notifyProgress();
  }

  Future<EpisodeMarkWriteResult> mark(PlaybackItem item) async {
    _ensureProgressAccount();
    var account = accountSession();
    if (_closed || account == null) {
      return const EpisodeMarkWriteResult(
        EpisodeMarkWriteStatus.failed,
        message: '请先登录 Bangumi',
      );
    }
    _items[EpisodeMarkState.itemKey(item)] = item;
    var resolution = await prepare(item);
    if (!_current(account)) {
      return const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.expired);
    }
    if (resolution.alreadyDone) {
      return const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.alreadyDone);
    }
    var candidate = resolution.candidate;
    if (candidate == null) {
      return EpisodeMarkWriteResult(
        EpisodeMarkWriteStatus.failed,
        message: resolution.message ?? '无法匹配章节，请在条目章节页手动标记',
      );
    }
    return confirm(candidate);
  }

  Future<EpisodeMarkResolution> prepare(PlaybackItem item) async {
    var account = accountSession();
    if (_closed || account == null) {
      return const EpisodeMarkResolution(message: '请先登录 Bangumi');
    }
    var subject = item.subject;
    if (subject == null || subject <= 0) {
      return const EpisodeMarkResolution(message: '该文件没有关联条目');
    }
    try {
      _links = await links.readAll();
      if (!_current(account)) return const EpisodeMarkResolution();
      if (_linkConflict(item)) {
        return const EpisodeMarkResolution(message: '文件已关联其他条目，请重新打开文件后标记');
      }
      if (_excluded(item)) {
        return const EpisodeMarkResolution(message: '该文件已设为不对应章节');
      }
      var linkedEpisode = _linkedEpisode(item);
      var evidence = extractEpisodeNumber(item.filePath);
      if (linkedEpisode == null &&
          evidence.kind != EpisodeNumberKind.single &&
          evidence.kind != EpisodeNumberKind.unknown) {
        return EpisodeMarkResolution(message: evidence.reason);
      }
      var key = '$account:$subject';
      var future = _pages.putIfAbsent(
        key,
        () => _allEpisodes(subject, account),
      );
      List<EpisodeMarkEpisode> episodes;
      try {
        episodes = await future;
      } finally {
        if (identical(_pages[key], future)) await _pages.remove(key);
      }
      if (!_current(account)) return const EpisodeMarkResolution();
      var episode = matchingEpisode(item, episodes, episodeId: linkedEpisode);
      if (episode == null) {
        return EpisodeMarkResolution(
          message: linkedEpisode != null
              ? '关联章节已不存在，请在条目详情重新关联文件'
              : evidence.kind == EpisodeNumberKind.unknown
              ? evidence.reason
              : '没有唯一匹配的章节，请手动选择',
        );
      }
      var done = await gateway.isDone(episode.id);
      if (!_current(account)) return const EpisodeMarkResolution();
      observeProgress(subject, [episode.withDone(done)], account: account);
      if (done) return const EpisodeMarkResolution(alreadyDone: true);
      return EpisodeMarkResolution(
        candidate: EpisodeMarkCandidate(
          item: item,
          account: account,
          episode: episode,
          number: evidence.number ?? episode.sort,
          linkedEpisode: linkedEpisode,
        ),
      );
    } catch (error) {
      if (!_current(account)) return const EpisodeMarkResolution();
      return EpisodeMarkResolution(message: error.toString(), retryable: true);
    }
  }

  Future<List<EpisodeMarkEpisode>> _allEpisodes(
    int subject,
    String account, {
    Future<EpisodeMarkPage> Function(int, int)? readPage,
  }) async {
    var items = <EpisodeMarkEpisode>[];
    var ids = <int>{};
    var offset = 0;
    int? expectedTotal;
    while (_current(account)) {
      var page = await (readPage ?? gateway.episodes)(subject, offset);
      if (!_current(account)) throw const EpisodeMarkFailure('账户会话已变化');
      if (page.offset != offset ||
          page.total < 0 ||
          (expectedTotal != null && page.total != expectedTotal)) {
        throw const EpisodeMarkFailure('章节分页已变化，请重试');
      }
      expectedTotal = page.total;
      if (page.episodes.isEmpty) {
        if (offset == page.total) return items;
        throw const EpisodeMarkFailure('章节列表未完整返回，请重试');
      }
      for (var episode in page.episodes) {
        if (!ids.add(episode.id)) {
          throw const EpisodeMarkFailure('章节分页重复，请重试');
        }
        items.add(episode);
      }
      offset += page.episodes.length;
      if (offset == page.total) return items;
      if (offset > page.total) {
        throw const EpisodeMarkFailure('章节分页数量异常，请重试');
      }
    }
    throw const EpisodeMarkFailure('账户会话已变化');
  }

  Future<EpisodeMarkWriteResult> confirm(EpisodeMarkCandidate candidate) {
    var key =
        '${candidate.account}:${candidate.subject}:${candidate.episode.id}';
    var existing = _writes[key];
    if (existing != null) return existing;
    late Future<EpisodeMarkWriteResult> future;
    future = _confirm(candidate).whenComplete(() {
      if (identical(_writes[key], future)) _writes.remove(key);
    });
    _writes[key] = future;
    return future;
  }

  Future<EpisodeMarkWriteResult> _confirm(
    EpisodeMarkCandidate candidate,
  ) async {
    if (!_current(candidate.account)) {
      return const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.expired);
    }
    try {
      // Always read back before every write/retry, including an unknown outcome
      // after timeout. Never toggle done back to none.
      var done = await gateway.isDone(candidate.episode.id);
      if (!_current(candidate.account)) {
        return const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.expired);
      }
      _links = await links.readAll();
      if (!_current(candidate.account) ||
          _linkConflict(candidate.item) ||
          _excluded(candidate.item) ||
          _linkedEpisode(candidate.item) != candidate.linkedEpisode) {
        return const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.expired);
      }
      if (!done) {
        await gateway.markDone(
          candidate.episode.id,
          authScope: () => _current(candidate.account),
        );
      }
      if (!_current(candidate.account)) {
        return const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.expired);
      }
      observeProgress(candidate.subject, [
        candidate.episode.withDone(true),
      ], account: candidate.account);
      // A successful remote write must still refresh UI if cache invalidation
      // fails. Do not change epStatus or whole-subject collection type locally.
      String? warning;
      try {
        await gateway.invalidateSubject(candidate.subject);
      } catch (_) {
        warning = '已标记看过，本地收藏缓存刷新失败，请手动刷新详情';
      }
      if (_current(candidate.account)) {
        _refreshes.add(
          EpisodeMarkRefresh(
            candidate.account,
            candidate.subject,
            candidate.episode.id,
          ),
        );
      } else {
        return const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.expired);
      }
      return EpisodeMarkWriteResult(
        done
            ? EpisodeMarkWriteStatus.alreadyDone
            : EpisodeMarkWriteStatus.marked,
        message: warning,
      );
    } catch (error) {
      if (!_current(candidate.account)) {
        return const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.expired);
      }
      return EpisodeMarkWriteResult(
        EpisodeMarkWriteStatus.failed,
        message: error.toString(),
      );
    }
  }

  void close() {
    _closed = true;
    unawaited(_linkSubscription.cancel());
    _pages.clear();
    _progressLoads.clear();
    unawaited(_progressChanges.close());
    unawaited(_refreshes.close());
  }
}
