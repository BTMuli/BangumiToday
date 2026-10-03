// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../../domain/repositories/bmf_repository.dart';
import '../../domain/repositories/playback_subjects.dart';
import '../../models/playback/playback_item.dart';

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
