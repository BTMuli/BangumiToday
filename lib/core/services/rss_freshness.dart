// Project imports:
import '../../models/database/app_rss_model.dart';

/// RSS 缓存的 freshness 判定策略。
///
/// 未过期且缓存版本匹配的订阅直接复用缓存，避免热启动或定时刷新
/// 无条件触发全量网络请求。
class RssFreshness {
  const RssFreshness({
    required this.window,
    this.cacheVersion = AppRssModel.currentCacheVersion,
  });

  /// 未过期缓存窗口。
  final Duration window;

  /// 当前缓存版本，与缓存记录不一致视为过期。
  final int cacheVersion;

  /// 缓存是否仍视为新鲜（可复用）。
  bool isFresh(AppRssModel? cached, DateTime now) {
    if (cached == null) return false;
    if (cached.data.isEmpty) return false;
    if (cached.cacheVersion != cacheVersion) return false;
    var ageMs = now.millisecondsSinceEpoch - cached.updated;
    // 时钟异常：记录时间在未来视为过期，避免长期跳过刷新。
    if (ageMs < 0) return false;
    return ageMs < window.inMilliseconds;
  }
}
