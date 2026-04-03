import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi_today/core/network/request_manager.dart';

void main() {
  group('RequestKey', () {
    test('calendar returns correct key', () {
      expect(RequestKey.calendar(), 'bangumi_calendar');
    });

    test('search returns correct key with keyword', () {
      expect(RequestKey.search('naruto', 0), 'search_naruto_0');
    });

    test('subjectDetail returns correct key', () {
      expect(RequestKey.subjectDetail(123), 'subject_detail_123');
    });

    test('subjectEpisodes returns correct key', () {
      expect(RequestKey.subjectEpisodes(456), 'subject_episodes_456');
    });

    test('userCollection returns correct key', () {
      expect(
        RequestKey.userCollection('user1', 789),
        'user_collection_user1_789',
      );
    });

    test('userCollections returns correct key', () {
      expect(RequestKey.userCollections('user1'), 'user_collections_user1');
    });

    test('rss returns correct key', () {
      expect(RequestKey.rss('mikan'), 'rss_mikan');
    });
  });
}
