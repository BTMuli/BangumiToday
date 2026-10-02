// Project imports:
import '../../models/bangumi/bangumi_model.dart';
import 'cache_manager.dart';

/// bgm 条目详情缓存。
///
/// 首页日历按 subject id 补封面、评分与收藏数，条目详情页每次加载也会走同一个
/// 接口。两边共用这一份缓存：详情页加载即刷新对应条目，首页只负责在没有较新
/// 记录时补一次，所以有效期设得比较短。
class BgmSubjectCache {
  BgmSubjectCache._();

  /// 实例
  static final BgmSubjectCache _instance = BgmSubjectCache._();

  /// 获取实例
  factory BgmSubjectCache() => _instance;

  /// 缓存有效期：3 天。
  ///
  /// 详情页看过或首页补过的条目在这段时间内直接用缓存，过期后由首页重新补。
  static const Duration maxAge = Duration(days: 3);

  /// 读取缓存的条目详情，过期或不存在时返回 null。
  Future<BangumiSubject?> read(int id) {
    return BTCacheManager.instance.getJson<BangumiSubject>(
      CacheKeys.subject(id),
      fromJson: BangumiSubject.fromJson,
      maxAge: maxAge,
    );
  }

  /// 写入条目详情，已存在时刷新时间戳。
  Future<void> write(BangumiSubject subject) {
    return BTCacheManager.instance.setJson<BangumiSubject>(
      CacheKeys.subject(subject.id),
      subject,
      toJson: (value) => value.toJson(),
      fromJson: BangumiSubject.fromJson,
    );
  }
}
