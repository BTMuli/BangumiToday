// Dart imports:
import 'dart:async';

// Project imports:
import '../../core/cache/subject_cache.dart';
import '../../domain/repositories/bangumi_repository.dart';
import '../../domain/repositories/playback_cover.dart';
import '../../models/bangumi/bangumi_model.dart';

/// 通过 Bangumi 仓储解析条目信息的封面实现，结果缓存在内存。
///
/// 只保留展示字段，优先复用详情缓存与本地收藏，同一条目的并发解析共用请求。
class BangumiPlaybackCoverResolver implements PlaybackCoverResolver {
  BangumiPlaybackCoverResolver(this._repository);

  final BTBangumiRepository _repository;
  final _subjects = <int, ({String name, String? cover})>{};
  final _pending = <int, Future<String?>>{};
  final _hydrating = <int, Future<bool>>{};

  @override
  bool contains(int subject) => _subjects.containsKey(subject);

  @override
  String? coverOf(int subject) => _subjects[subject]?.cover;

  @override
  String? nameOf(int subject) => _subjects[subject]?.name;

  @override
  Future<bool> hydrate(int subject) {
    if (contains(subject)) return Future.value(true);
    return _hydrating.putIfAbsent(subject, () => _hydrate(subject));
  }

  Future<bool> _hydrate(int subject) async {
    try {
      var cached = await _readLocal(subject);
      if (cached == null) return false;
      _subjects.putIfAbsent(subject, () => cached);
      return true;
    } finally {
      unawaited(_hydrating.remove(subject));
    }
  }

  @override
  Future<String?> resolve(int subject) {
    if (contains(subject)) return Future.value(coverOf(subject));
    return _pending.putIfAbsent(subject, () => _resolve(subject));
  }

  Future<String?> _resolve(int subject) async {
    try {
      if (await hydrate(subject)) return coverOf(subject);
      try {
        var response = await _repository.getSubjectDetail(subject.toString());
        var data = response.code == 0 ? response.data : null;
        if (data != null) {
          var name = _firstNonEmpty([data.nameCn, data.name]);
          if (name != null) {
            _subjects[subject] = (name: name, cover: _image(data.images));
            // 原名同样可用于展示，持久化后重启也不必重复请求详情。
            await _writeCache(data);
          }
        }
      } catch (_) {
        // 保留文件名作为暂时回退；下一次打开记录或手动刷新时允许重试。
      }
      return coverOf(subject);
    } finally {
      unawaited(_pending.remove(subject));
    }
  }

  /// 只读本地数据，允许复用过期详情；收藏里的名称也可独立用于历史标题。
  Future<({String name, String? cover})?> _readLocal(int subject) async {
    BangumiSubject? cached;
    try {
      cached = await BgmSubjectCache().read(subject, allowStale: true);
    } catch (_) {}
    if (cached != null && cached.nameCn.trim().isNotEmpty) {
      return (name: cached.nameCn.trim(), cover: _image(cached.images));
    }
    BangumiSlimSubject? collected;
    try {
      collected = (await _repository.getLocalCollection(subject))?.subject;
    } catch (_) {}
    var name = _firstNonEmpty([
      collected?.nameCn ?? '',
      cached?.name ?? '',
      collected?.name ?? '',
    ]);
    return name == null
        ? null
        : (
            name: name,
            cover: _image(cached?.images) ?? _image(collected?.images),
          );
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
      if (value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String? _image(BangumiImages? images) => images == null
      ? null
      : _firstNonEmpty([
          images.large,
          images.medium,
          images.common,
          images.grid,
        ]);
}
