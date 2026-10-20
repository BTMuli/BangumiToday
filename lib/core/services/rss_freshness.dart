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

  bool isMetadataFresh(AppRssCacheMetadata? cache, DateTime now) {
    if (cache == null ||
        !cache.hasData ||
        cache.lastSuccessAt == 0 ||
        cache.cacheVersion != cacheVersion) {
      return false;
    }
    var age = now.millisecondsSinceEpoch - cache.lastSuccessAt;
    // A feed's advisory TTL must not extend the client's polling window.
    return age >= 0 && age < window.inMilliseconds;
  }
}
