// Project imports:
import '../../domain/repositories/bangumi_repository.dart';
import '../../models/bangumi/bangumi_model.dart';

/// Matching needs the complete chapter list, including missing local episodes.
Future<List<BangumiEpisode>> loadPlaybackEpisodes(
  BTBangumiRepository repository,
  int subject, {
  bool Function()? isCurrent,
}) async {
  try {
    var episodes = <BangumiEpisode>[];
    var ids = <int>{};
    int? total;
    while (true) {
      var response = await repository.getEpisodeList(
        subject,
        limit: 100,
        offset: episodes.length,
      );
      if (isCurrent != null && !isCurrent()) return const [];
      var page = response.data;
      if (response.code != 0 || page == null) {
        throw StateError('获取章节失败：${response.message}');
      }
      if (page.offset != episodes.length ||
          page.total < episodes.length ||
          (total != null && total != page.total)) {
        throw StateError('章节分页已变化，请重试');
      }
      total = page.total;
      for (var episode in page.data) {
        if (!ids.add(episode.id)) throw StateError('章节分页重复，请重试');
        episodes.add(episode);
      }
      if (episodes.length == total) return episodes;
      if (page.data.isEmpty || episodes.length > total) {
        throw StateError('章节列表未完整返回，请重试');
      }
    }
  } catch (_) {
    // 分页总数或边界变化时，重试必须重新读取整份列表。
    repository.invalidateEpisodeList(subject);
    rethrow;
  }
}
