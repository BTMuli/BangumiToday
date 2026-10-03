// Project imports:
import '../../domain/repositories/bangumi_repository.dart';
import '../../domain/repositories/playback_cover.dart';
import '../../models/bangumi/bangumi_model.dart';

/// 通过 Bangumi 仓储解析条目信息的封面实现，结果缓存在内存。
///
/// 只保留解析出的字段，图片字节由 `CachedNetworkImage` 另行缓存；查询失败记
/// 为 `null`，避免重复请求。
class BangumiPlaybackCoverResolver implements PlaybackCoverResolver {
  BangumiPlaybackCoverResolver(this._repository);

  final BTBangumiRepository _repository;
  final Map<int, BangumiSubject?> _subjects = {};
  final Set<int> _inFlight = {};

  @override
  bool contains(int subject) => _subjects.containsKey(subject);

  @override
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

  @override
  String? nameOf(int subject) {
    var data = _subjects[subject];
    if (data == null) return null;
    return data.nameCn.isNotEmpty ? data.nameCn : data.name;
  }

  @override
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
