// Project imports:
import '../../models/bangumi/bangumi_model_episode.dart';

typedef SubjectEpisodeProgress = ({int done, int? total, bool complete});

/// 按章节 ID 计数，不把续作的放送编号或收藏汇总当成已看集数。
SubjectEpisodeProgress summarizeSubjectEpisodes(
  Iterable<BangumiEpisode> episodes,
  Map<int, bool> progress, {
  bool complete = true,
  int declaredTotal = 0,
}) {
  var ids = episodes.map((episode) => episode.id).toSet();
  return (
    done: ids.where((id) => progress[id] == true).length,
    total: complete ? ids.length : (declaredTotal > 0 ? declaredTotal : null),
    complete: complete && ids.every(progress.containsKey),
  );
}
