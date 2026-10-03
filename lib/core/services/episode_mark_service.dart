// Dart imports:
import 'dart:async';

// Project imports:
import '../../domain/repositories/episode_mark_gateway.dart';
import '../../models/playback/playback_completion.dart';
import '../utils/episode_num_extractor.dart';

class EpisodeMarkCandidate {
  const EpisodeMarkCandidate({
    required this.completion,
    required this.account,
    required this.episode,
    required this.number,
  });

  final PlaybackCompletion completion;
  final String account;
  final EpisodeMarkEpisode episode;
  final int number;

  int get subject => completion.item.subject!;
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

/// Network work never joins the playback operation queue. No unconfirmed writes
/// are persisted or retried automatically.
class EpisodeMarkService {
  EpisodeMarkService({required this.gateway, required this.accountSession});

  final EpisodeMarkGateway gateway;
  final String? Function() accountSession;
  final _pages = <String, Future<List<EpisodeMarkEpisode>>>{};
  final _writes = <String, Future<EpisodeMarkWriteResult>>{};
  final _refreshes = StreamController<EpisodeMarkRefresh>.broadcast();
  bool _closed = false;

  Stream<EpisodeMarkRefresh> get refreshes => _refreshes.stream;

  bool _current(String account) => !_closed && accountSession() == account;

  Future<EpisodeMarkResolution> prepare(PlaybackCompletion completion) async {
    var account = accountSession();
    if (_closed || account == null) {
      return const EpisodeMarkResolution(message: '请先登录 Bangumi');
    }
    var subject = completion.item.subject;
    if (subject == null || subject <= 0) {
      return const EpisodeMarkResolution(message: '该文件没有关联条目');
    }
    var evidence = extractEpisodeNumber(completion.item.filePath);
    if (evidence.kind != EpisodeNumberKind.single) {
      return EpisodeMarkResolution(message: evidence.reason);
    }
    try {
      var key = '$account:$subject';
      var future = _pages.putIfAbsent(
        key,
        () => _allEpisodes(subject, account),
      );
      List<EpisodeMarkEpisode> episodes;
      try {
        episodes = await future;
      } finally {
        if (identical(_pages[key], future)) _pages.remove(key);
      }
      if (!_current(account)) return const EpisodeMarkResolution();
      var matches = episodes
          .where(
            (episode) =>
                episode.type == 0 &&
                episode.id > 0 &&
                episode.sort.isFinite &&
                episode.sort == evidence.number,
          )
          .toList();
      if (matches.length != 1) {
        return const EpisodeMarkResolution(message: '没有唯一匹配的正片章节，请手动选择');
      }
      var episode = matches.single;
      var withinSubject = episode.withinSubject;
      if (withinSubject != null &&
          withinSubject > 0 &&
          withinSubject != episode.sort) {
        return const EpisodeMarkResolution(message: '章节排序与条目内编号不同，请手动确认章节');
      }
      var done = await gateway.isDone(episode.id);
      if (!_current(account)) return const EpisodeMarkResolution();
      if (done) return const EpisodeMarkResolution(alreadyDone: true);
      return EpisodeMarkResolution(
        candidate: EpisodeMarkCandidate(
          completion: completion,
          account: account,
          episode: episode,
          number: evidence.number!,
        ),
      );
    } catch (error) {
      if (!_current(account)) return const EpisodeMarkResolution();
      return EpisodeMarkResolution(message: error.toString(), retryable: true);
    }
  }

  Future<List<EpisodeMarkEpisode>> _allEpisodes(
    int subject,
    String account,
  ) async {
    var items = <EpisodeMarkEpisode>[];
    var ids = <int>{};
    var offset = 0;
    int? expectedTotal;
    while (_current(account)) {
      var page = await gateway.episodes(subject, offset);
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
      if (!done) {
        await gateway.markDone(
          candidate.episode.id,
          authScope: () => _current(candidate.account),
        );
      }
      if (!_current(candidate.account)) {
        return const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.expired);
      }
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
    _pages.clear();
    unawaited(_refreshes.close());
  }
}
