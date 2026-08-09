import 'dart:async';

import 'package:bangumi_today/request/bangumi/bangumi_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RequestKey', () {
    test('calendar returns correct key', () {
      expect(RequestKey.calendar(), 'bangumi_calendar');
    });

    test('search returns correct key with keyword', () {
      expect(RequestKey.search('naruto', 0), 'search_naruto_0');
    });

    test('search keeps tag filters isolated', () {
      expect(RequestKey.search('', 0, tag: ['action']), 'search__0_tag_action');
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

  group('RequestManager', () {
    late RequestManager manager;

    setUp(() {
      manager = RequestManager();
      manager.cancelAll();
    });

    tearDown(() {
      manager.cancelAll();
    });

    test('deduplicates concurrent requests with the same key', () async {
      var requestCount = 0;
      var response = Completer<int>();

      Future<int> request(CancelToken _) {
        requestCount++;
        return response.future;
      }

      var first = manager.request(key: 'same', request: request);
      var second = manager.request(key: 'same', request: request);
      response.complete(42);

      expect(await Future.wait([first, second]), [42, 42]);
      expect(requestCount, 1);
      expect(manager.isPending('same'), isFalse);
    });

    test(
      'cancelPrevious replaces rather than reuses the pending request',
      () async {
        var first = manager.request<int>(
          key: 'replace',
          request: (token) async {
            await token.whenCancel;
            throw token.cancelError!;
          },
        );
        var firstExpectation = expectLater(first, throwsA(isA<DioException>()));

        var second = manager.request<int>(
          key: 'replace',
          cancelPrevious: true,
          request: (_) async => 2,
        );

        await firstExpectation;
        expect(await second, 2);
        expect(manager.isPending('replace'), isFalse);
      },
    );

    test('a cancelled request cannot remove its replacement', () async {
      var releaseReplacement = Completer<int>();
      var first = manager.request<int>(
        key: 'race',
        request: (token) async {
          await token.whenCancel;
          throw token.cancelError!;
        },
      );
      var firstExpectation = expectLater(first, throwsA(isA<DioException>()));

      var replacement = manager.request<int>(
        key: 'race',
        cancelPrevious: true,
        request: (_) => releaseReplacement.future,
      );
      await firstExpectation;

      expect(manager.isPending('race'), isTrue);
      releaseReplacement.complete(3);
      expect(await replacement, 3);
      expect(manager.isPending('race'), isFalse);
    });

    test(
      'a synchronous failure does not leave a stale deduplication',
      () async {
        var requestCount = 0;

        Future<int> request(CancelToken _) {
          requestCount++;
          throw StateError('synchronous failure');
        }

        await expectLater(
          manager.request<int>(key: 'sync_failure', request: request),
          throwsStateError,
        );
        await expectLater(
          manager.request<int>(key: 'sync_failure', request: request),
          throwsStateError,
        );

        expect(requestCount, 2);
        expect(manager.isPending('sync_failure'), isFalse);
      },
    );
  });
}
