// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/rss_freshness.dart';
import 'package:bangumi_today/models/database/app_rss_model.dart';

void main() {
  const window = Duration(minutes: 30);
  const freshness = RssFreshness(window: window);
  var now = DateTime(2026, 8, 9, 12);

  AppRssModel cached({
    int ageMs = 60 * 1000,
    int cacheVersion = AppRssModel.currentCacheVersion,
    String data = '<rss />',
  }) {
    return AppRssModel(
      rss: 'https://example.com/feed.xml',
      data: data,
      ttl: 15,
      updated: now.millisecondsSinceEpoch - ageMs,
      cacheVersion: cacheVersion,
    );
  }

  test('reuses a cache inside the freshness window', () {
    expect(freshness.isFresh(cached(), now), isTrue);
  });

  test('treats a cache beyond the window as expired', () {
    expect(
      freshness.isFresh(cached(ageMs: window.inMilliseconds + 1), now),
      isFalse,
    );
  });

  test('treats the window boundary as expired', () {
    expect(
      freshness.isFresh(cached(ageMs: window.inMilliseconds), now),
      isFalse,
    );
  });

  test('returns false when there is no cache', () {
    expect(freshness.isFresh(null, now), isFalse);
  });

  test('returns false when the cached data is empty', () {
    expect(freshness.isFresh(cached(data: ''), now), isFalse);
  });

  test('returns false when the cache version does not match', () {
    expect(freshness.isFresh(cached(cacheVersion: 0), now), isFalse);
  });

  test('treats a future timestamp as expired to survive clock anomalies', () {
    expect(freshness.isFresh(cached(ageMs: -1000), now), isFalse);
  });
}
