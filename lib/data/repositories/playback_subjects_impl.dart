// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../../domain/repositories/bmf_repository.dart';
import '../../domain/repositories/playback_episode_links.dart';
import '../../domain/repositories/playback_subjects.dart';
import '../../models/playback/playback_item.dart';

/// 优先使用文件章节关联，否则取匹配到的最长 BMF 下载目录。
class BmfPlaybackSubjectResolver implements PlaybackSubjectResolver {
  BmfPlaybackSubjectResolver(this._bmf, this._links);

  final BmfRepository _bmf;
  final PlaybackEpisodeLinks _links;

  @override
  Future<int?> subjectForFile(String filePath) async {
    var key = PlaybackItem.pathKey(filePath);
    var linked = (await _links.readAll())[key];
    if (linked != null) return linked.subject;
    var associations = await _bmf.readAll();
    associations.sort(
      (a, b) => (b.download?.length ?? 0).compareTo(a.download?.length ?? 0),
    );
    for (var association in associations) {
      var root = association.download;
      if (root != null &&
          root.isNotEmpty &&
          path.isWithin(PlaybackItem.pathKey(root), key)) {
        return association.subject;
      }
    }
    return null;
  }
}
