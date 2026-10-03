// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../../domain/repositories/bmf_repository.dart';
import '../../models/playback/playback_item.dart';

/// 本地视频与 Bangumi 条目的归属解析接口。
///
/// 播放入口只依赖该契约，不再直接查询 BMF 表。
abstract class PlaybackSubjectResolver {
  /// 视频路径所属订阅的 Bangumi 条目 ID，未匹配时为 null。
  Future<int?> subjectForFile(String filePath);
}

/// 按 BMF 订阅的下载目录解析归属，取匹配到的最长目录。
class BmfPlaybackSubjectResolver implements PlaybackSubjectResolver {
  BmfPlaybackSubjectResolver(this._bmf);

  final BmfRepository _bmf;

  @override
  Future<int?> subjectForFile(String filePath) async {
    var key = PlaybackItem.pathKey(filePath);
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
