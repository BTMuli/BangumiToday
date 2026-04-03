import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi_today/core/cache/cache_manager.dart';

void main() {
  group('CacheDuration', () {
    test('short is 15 minutes', () {
      expect(CacheDuration.short, const Duration(minutes: 15));
    });

    test('medium is 6 hours', () {
      expect(CacheDuration.medium, const Duration(hours: 6));
    });

    test('long is 1 day', () {
      expect(CacheDuration.long, const Duration(days: 1));
    });

    test('veryLong is 7 days', () {
      expect(CacheDuration.veryLong, const Duration(days: 7));
    });
  });

  group('CacheKeys', () {
    test('bangumiCalendar returns correct key', () {
      expect(CacheKeys.bangumiCalendar, 'bangumi_calendar');
    });

    test('subject returns correct key with id', () {
      expect(CacheKeys.subject(123), 'bangumi_subject_123');
    });

    test('episodes returns correct key with id', () {
      expect(CacheKeys.episodes(456), 'bangumi_episodes_456');
    });

    test('search returns correct key', () {
      expect(CacheKeys.search('naruto', 0), 'search_result_naruto_0');
    });

    test('rss returns correct key', () {
      expect(CacheKeys.rss('mikan'), 'rss_data_mikan');
    });
  });
}
