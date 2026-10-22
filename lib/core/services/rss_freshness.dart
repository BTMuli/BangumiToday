// Project imports:
import '../../models/database/app_rss_cache_model.dart';

class RssFreshness {
  const RssFreshness({
    required this.window,
    this.cacheVersion = AppRssCacheModel.currentCacheVersion,
  });
  final Duration window;
  final int cacheVersion;

  bool isFresh(AppRssCacheModel? cache, DateTime now) {
    return isMetadataFresh(
      cache == null
          ? null
          : AppRssCacheMetadata(
              hasData: cache.data?.isNotEmpty ?? false,
              ttlMinutes: cache.ttlMinutes,
              lastSuccessAt: cache.lastSuccessAt,
              lastFailedAt: cache.lastFailedAt,
              cacheVersion: cache.cacheVersion,
            ),
      now,
    );
  }

  /// 缓存的精确到期时刻，用于在到期时直接唤醒刷新。
  DateTime? expiresAt(AppRssCacheMetadata? cache) {
    if (cache == null ||
        !cache.hasData ||
        cache.lastSuccessAt == 0 ||
        cache.cacheVersion != cacheVersion) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(cache.lastSuccessAt).add(window);
  }

  bool isMetadataFresh(AppRssCacheMetadata? cache, DateTime now) {
    var expiry = expiresAt(cache);
    if (expiry == null) return false;
    var age = now.millisecondsSinceEpoch - cache!.lastSuccessAt;
    // A feed's advisory TTL must not extend the client's polling window.
    return age >= 0 && now.isBefore(expiry);
  }
}
