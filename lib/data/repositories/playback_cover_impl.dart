// Project imports:
import '../../core/cache/subject_cache.dart';
import '../../domain/repositories/bangumi_repository.dart';
import '../../domain/repositories/playback_cover.dart';
import '../../models/bangumi/bangumi_model.dart';

/// 通过 Bangumi 仓储解析条目信息的封面实现，结果缓存在内存。
///
/// 只保留解析出的字段，图片字节由 `CachedNetworkImage` 另行缓存；查询失败记
/// 为 `null`，避免重复请求。条目名与封面都是静态展示字段，解析前先看请求层
/// 写下的 [BgmSubjectCache]：播放记录、选集与首页日历因此共用同一份磁盘缓存。
class BangumiPlaybackCoverResolver implements PlaybackCoverResolver {
  BangumiPlaybackCoverResolver(this._repository);

  final BTBangumiRepository _repository;
  final Map<int, BangumiSubject?> _subjects = {};
  final Set<int> _inFlight = {};
  final Set<int> _hydrating = {};

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
  Future<bool> hydrate(int subject) async {
    if (_subjects.containsKey(subject)) return _subjects[subject] != null;
    if (!_hydrating.add(subject)) return false;
    try {
      var cached = await _readCache(subject);
      // 列表标题要的是译名；缓存里恰好缺译名的条目留给真正的解析去补。
      if (cached == null || cached.nameCn.isEmpty) return false;
      _subjects[subject] = cached;
      return true;
    } finally {
      _hydrating.remove(subject);
    }
  }

  @override
  Future<String?> resolve(int subject) async {
    if (_subjects.containsKey(subject)) return coverOf(subject);
    if (!_inFlight.add(subject)) return null;
    try {
      var cached = await _readCache(subject);
      BangumiSubject? data;
      if (cached != null && cached.nameCn.isNotEmpty) {
        // 覆盖仍有中文名就直接用，不再为播放记录重建一次请求。
        data = cached;
      } else {
        try {
          var response = await _repository.getSubjectDetail(subject.toString());
          data = response.code == 0 ? response.data : null;
        } catch (_) {
          data = null;
        }
        // 仓储会用本地 bangumi-data 补上没有译名的条目：把补过的结果写回
        // 缓存，下次连这一次详情请求也省掉。
        if (data != null && data.nameCn.isNotEmpty) await _writeCache(data);
      }
      _subjects[subject] = data;
      return coverOf(subject);
    } finally {
      _inFlight.remove(subject);
    }
  }

  /// 只读磁盘缓存，允许用过期的条目名与封面。
  Future<BangumiSubject?> _readCache(int subject) async {
    try {
      return await BgmSubjectCache().read(subject, allowStale: true);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(BangumiSubject subject) async {
    try {
      await BgmSubjectCache().write(subject);
    } catch (_) {
      // 写缓存只是加速下次展示，失败不影响本次解析结果。
    }
  }

  static String? _firstNonEmpty(List<String> values) {
    for (var value in values) {
      if (value.isNotEmpty) return value;
    }
    return null;
  }
}
