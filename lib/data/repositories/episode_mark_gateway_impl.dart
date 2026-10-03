// Project imports:
import '../../domain/repositories/bangumi_repository.dart';
import '../../domain/repositories/episode_mark_gateway.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../datasources/bangumi_local_data_source.dart';

class BangumiEpisodeMarkGateway implements EpisodeMarkGateway {
  BangumiEpisodeMarkGateway(this.repository, this.local);

  final BTBangumiRepository repository;
  final BTBangumiLocalDataSource local;

  @override
  Future<EpisodeMarkPage> episodes(int subject, int offset) async {
    var response = await repository.getEpisodeList(
      subject,
      limit: 100,
      offset: offset,
    );
    var page = response.data;
    if (response.code != 0 || page == null) {
      throw EpisodeMarkFailure('获取章节失败：${response.message}');
    }
    return EpisodeMarkPage(
      total: page.total,
      offset: page.offset,
      episodes: List.unmodifiable(
        page.data.map(
          (episode) => EpisodeMarkEpisode(
            id: episode.id,
            type: episode.type.value,
            sort: episode.sort,
            withinSubject: episode.ep,
            name: episode.nameCn.isEmpty ? episode.name : episode.nameCn,
          ),
        ),
      ),
    );
  }

  @override
  Future<bool> isDone(int episode) async {
    var response = await repository.getCollectionEpisode(episode);
    if (response.code != 0 || response.data == null) {
      throw EpisodeMarkFailure(
        '无法读取章节收藏，请确认已登录且条目已收藏：'
        '${response.message}',
      );
    }
    return response.data!.type == BangumiEpisodeCollectionType.done;
  }

  @override
  Future<void> markDone(
    int episode, {
    required bool Function() authScope,
  }) async {
    if (!authScope()) throw const EpisodeMarkFailure('账户会话已变化');
    var response = await repository.updateCollectionEpisode(
      type: BangumiEpisodeCollectionType.done,
      episode: episode,
      authScope: authScope,
    );
    if (response.code != 0) {
      throw EpisodeMarkFailure('标记看过失败：${response.message}');
    }
  }

  @override
  Future<void> invalidateSubject(int subject) =>
      local.deleteCollection(subject);
}
