// Project imports:
import '../../domain/repositories/bangumi_repository.dart';
import '../../domain/repositories/episode_mark_gateway.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';

EpisodeMarkEpisode episodeMarkChapter(BangumiEpisode episode) =>
    EpisodeMarkEpisode(
      id: episode.id,
      type: episode.type.value,
      sort: episode.sort,
      withinSubject: episode.ep,
      name: episode.nameCn.isEmpty ? episode.name : episode.nameCn,
    );

EpisodeMarkEpisode episodeMarkProgress(BangumiUserEpisodeCollection value) =>
    EpisodeMarkEpisode(
      id: value.episode.id,
      type: value.episode.type.value,
      sort: value.episode.sort,
      withinSubject: value.episode.ep,
      name: value.episode.nameCn.isEmpty
          ? value.episode.name
          : value.episode.nameCn,
      done: value.type == BangumiEpisodeCollectionType.done,
      collected: value.type != BangumiEpisodeCollectionType.none,
    );

class BangumiEpisodeMarkGateway implements EpisodeMarkGateway {
  BangumiEpisodeMarkGateway(this.repository);

  final BTBangumiRepository repository;

  static bool _retryable(int code) =>
      code == 666 || code == 408 || const [500, 502, 503, 504].contains(code);

  static Future<void> _retryDelay(int attempt) =>
      Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));

  /// Reads can recover from a transient failure without joining playback work.
  Future<BTResponse<T>> _read<T>(
    Future<BTResponse<T>> Function() request, {
    bool Function()? authScope,
  }) async {
    for (var attempt = 0; ; attempt++) {
      if (authScope != null && !authScope()) {
        throw const EpisodeMarkFailure('账户会话已变化');
      }
      var response = await request();
      if (!_retryable(response.code) || attempt >= 2) return response;
      await _retryDelay(attempt);
    }
  }

  @override
  Future<EpisodeMarkPage> episodes(int subject, int offset) async {
    var response = await _read(
      () => repository.getEpisodeList(subject, limit: 100, offset: offset),
    );
    var page = response.data;
    if (response.code != 0 || page == null) {
      throw EpisodeMarkFailure('获取章节失败：${response.message}');
    }
    return EpisodeMarkPage(
      total: page.total,
      offset: page.offset,
      episodes: List.unmodifiable(page.data.map(episodeMarkChapter)),
    );
  }

  @override
  Future<bool> isDone(int episode) async {
    var response = await _read(() => repository.getCollectionEpisode(episode));
    if (response.code != 0 || response.data == null) {
      var hint = switch (response.code) {
        401 => '请重新登录 Bangumi：',
        404 => '请确认条目已收藏：',
        _ => '',
      };
      throw EpisodeMarkFailure('无法读取章节收藏：$hint${response.message}');
    }
    return response.data!.type == BangumiEpisodeCollectionType.done;
  }

  @override
  Future<EpisodeMarkPage> progress(int subject, int offset) async {
    var response = await _read(
      () =>
          repository.getCollectionEpisodes(subject, limit: 100, offset: offset),
    );
    var page = response.data;
    if (response.code != 0 || page == null) {
      throw EpisodeMarkFailure('获取章节观看进度失败：${response.message}');
    }
    return EpisodeMarkPage(
      total: page.total,
      offset: page.offset,
      episodes: List.unmodifiable(page.data.map(episodeMarkProgress)),
    );
  }

  @override
  Future<void> markDone(
    int episode, {
    required bool Function() authScope,
  }) async {
    for (var attempt = 0; ; attempt++) {
      if (!authScope()) throw const EpisodeMarkFailure('账户会话已变化');
      var response = await repository.updateCollectionEpisode(
        type: BangumiEpisodeCollectionType.done,
        episode: episode,
        authScope: authScope,
      );
      if (response.code == 0) return;
      if (!_retryable(response.code)) {
        throw EpisodeMarkFailure('标记看过失败：${response.message}');
      }
      if (attempt < 2) await _retryDelay(attempt);
      if (!authScope()) throw const EpisodeMarkFailure('账户会话已变化');
      // A failed reply does not prove the write failed. Read it back before
      // retrying, always against this captured episode rather than playback.
      if (await isDone(episode)) return;
      if (attempt >= 2) {
        throw EpisodeMarkFailure('标记看过失败：${response.message}');
      }
    }
  }

  @override
  Future<void> saveProgress(
    int subject,
    int collectedEpisodes, {
    required bool Function() authScope,
  }) async {
    var response = await repository.saveLocalCollectionProgress(
      subject,
      collectedEpisodes,
      authScope: authScope,
    );
    if (response.code != 0) {
      throw EpisodeMarkFailure('保存本地收藏进度失败：${response.message}');
    }
  }
}
