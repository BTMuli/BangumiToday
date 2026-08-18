// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Project imports:
import 'package:bangumi_today/data/datasources/bangumi_local_data_source.dart';
import 'package:bangumi_today/data/datasources/bangumi_remote_data_source.dart';
import 'package:bangumi_today/data/repositories/bangumi_repository_impl.dart';
import 'package:bangumi_today/domain/repositories/bangumi_repository.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/models/bangumi/request_subject.dart';
import 'bangumi_repository_test.mocks.dart';

@GenerateMocks([BTBangumiRemoteDataSource, BTBangumiLocalDataSource])
void main() {
  late BTBangumiRepository repository;
  late MockBTBangumiRemoteDataSource mockRemoteDataSource;
  late MockBTBangumiLocalDataSource mockLocalDataSource;

  setUp(() {
    mockRemoteDataSource = MockBTBangumiRemoteDataSource();
    mockLocalDataSource = MockBTBangumiLocalDataSource();
    repository = BTBangumiRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      localDataSource: mockLocalDataSource,
    );
  });

  group('BTBangumiRepository', () {
    test('getToday returns data from remote data source', () async {
      var mockData = <BangumiCalendarRespData>[];
      when(mockRemoteDataSource.getToday()).thenAnswer(
        (_) async => BTResponse(code: 0, message: 'success', data: mockData),
      );

      var result = await repository.getToday();

      expect(result.code, 0);
      verify(mockRemoteDataSource.getToday()).called(1);
    });

    test('getToday returns error when remote fails', () async {
      when(mockRemoteDataSource.getToday()).thenAnswer(
        (_) async =>
            BTResponse.error(code: 500, message: 'Server Error', data: null),
      );

      var result = await repository.getToday();

      expect(result.code, 500);
      expect(result.message, 'Server Error');
    });

    test(
      'searchSubjects calls remote data source with correct params',
      () async {
        when(
          mockRemoteDataSource.searchSubjects(
            any,
            sort: anyNamed('sort'),
            offset: anyNamed('offset'),
            limit: anyNamed('limit'),
            type: anyNamed('type'),
            tag: anyNamed('tag'),
            airdate: anyNamed('airdate'),
            rating: anyNamed('rating'),
            rank: anyNamed('rank'),
            nsfw: anyNamed('nsfw'),
          ),
        ).thenAnswer(
          (_) async => BTResponse(code: 0, message: 'success', data: null),
        );

        await repository.searchSubjects('naruto', limit: 10);

        verify(
          mockRemoteDataSource.searchSubjects(
            'naruto',
            sort: 'match',
            offset: 0,
            limit: 10,
            type: anyNamed('type'),
            tag: anyNamed('tag'),
            airdate: anyNamed('airdate'),
            rating: anyNamed('rating'),
            rank: anyNamed('rank'),
            nsfw: anyNamed('nsfw'),
          ),
        ).called(1);
      },
    );

    test('getCollectionSubject writes remote success to local', () async {
      var collection = _collection();
      when(
        mockRemoteDataSource.getCollectionSubject('1', 42),
      ).thenAnswer((_) async => BTResponse.success(data: collection));
      when(
        mockLocalDataSource.insertCollection(collection),
      ).thenAnswer((_) async {});

      var result = await repository.getCollectionSubject('1', 42);

      expect(result.code, 0);
      expect(result.data, collection);
      verify(mockLocalDataSource.insertCollection(collection)).called(1);
    });

    test('getCollectionSubject falls back to local on remote error', () async {
      var cached = _collection();
      when(mockRemoteDataSource.getCollectionSubject('1', 42)).thenAnswer(
        (_) async =>
            BTResponse.error(code: 500, message: 'Server Error', data: null),
      );
      when(
        mockLocalDataSource.getCollection(42),
      ).thenAnswer((_) async => cached);

      var result = await repository.getCollectionSubject('1', 42);

      expect(result.code, 0);
      expect(result.data, cached);
      verify(mockLocalDataSource.getCollection(42)).called(1);
      verifyNever(mockLocalDataSource.deleteCollection(42));
    });

    test('getCollectionSubject deletes local on remote 404', () async {
      when(mockRemoteDataSource.getCollectionSubject('1', 42)).thenAnswer(
        (_) async =>
            BTResponse.error(code: 404, message: 'missing', data: null),
      );
      when(mockLocalDataSource.deleteCollection(42)).thenAnswer((_) async {});

      var result = await repository.getCollectionSubject('1', 42);

      expect(result.code, 404);
      verify(mockLocalDataSource.deleteCollection(42)).called(1);
      verifyNever(mockLocalDataSource.getCollection(42));
    });

    test(
      'getCollectionSubjects writes the remote page then falls back locally',
      () async {
        var collection = _collection();
        var page = BangumiPageT<BangumiUserSubjectCollection>(
          total: 1,
          limit: 50,
          offset: 0,
          data: [collection],
        );
        when(
          mockRemoteDataSource.getCollectionSubjects(
            username: anyNamed('username'),
            subjectType: anyNamed('subjectType'),
            collectionType: anyNamed('collectionType'),
            limit: anyNamed('limit'),
            offset: anyNamed('offset'),
          ),
        ).thenAnswer((_) async => BTResponse.success(data: page));
        when(
          mockLocalDataSource.writeList([collection]),
        ).thenAnswer((_) async {});

        var result = await repository.getCollectionSubjects(
          username: '1',
          collectionType: BangumiCollectionType.doing,
        );

        expect(result.code, 0);
        verify(mockLocalDataSource.writeList([collection])).called(1);
      },
    );

    test(
      'getCollectionSubjects returns local list when remote fails',
      () async {
        var cached = _collection();
        when(
          mockRemoteDataSource.getCollectionSubjects(
            username: anyNamed('username'),
            subjectType: anyNamed('subjectType'),
            collectionType: anyNamed('collectionType'),
            limit: anyNamed('limit'),
            offset: anyNamed('offset'),
          ),
        ).thenAnswer(
          (_) async =>
              BTResponse.error(code: 500, message: 'Server Error', data: null),
        );
        when(
          mockLocalDataSource.getByType(BangumiCollectionType.doing),
        ).thenAnswer((_) async => [cached]);

        var result = await repository.getCollectionSubjects(
          collectionType: BangumiCollectionType.doing,
        );

        expect(result.code, 0);
        expect(result.data?.data, [cached]);
        expect(result.data?.total, 1);
      },
    );

    test('getLocalCollection reads from local data source', () async {
      var cached = _collection();
      when(
        mockLocalDataSource.getCollection(42),
      ).thenAnswer((_) async => cached);

      var result = await repository.getLocalCollection(42);

      expect(result, cached);
      verify(mockLocalDataSource.getCollection(42)).called(1);
    });

    test(
      'updateCollectionSubject writes patched local row after remote success',
      () async {
        var existing = _collection();
        when(
          mockRemoteDataSource.updateCollectionSubject(
            42,
            type: BangumiCollectionType.collect,
            rate: 9,
            ep: anyNamed('ep'),
            vol: anyNamed('vol'),
            comment: anyNamed('comment'),
            private: anyNamed('private'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => BTResponse.success(data: null));
        when(
          mockLocalDataSource.getCollection(42),
        ).thenAnswer((_) async => existing);
        when(
          mockLocalDataSource.updateCollection(existing),
        ).thenAnswer((_) async {});

        var result = await repository.updateCollectionSubject(
          42,
          type: BangumiCollectionType.collect,
          rate: 9,
        );

        expect(result.code, 0);
        expect(existing.type, BangumiCollectionType.collect);
        expect(existing.rate, 9);
        verify(mockLocalDataSource.updateCollection(existing)).called(1);
      },
    );
  });
}

BangumiUserSubjectCollection _collection() {
  return BangumiUserSubjectCollection(
    subjectId: 42,
    subjectType: BangumiSubjectType.anime,
    rate: 8,
    type: BangumiCollectionType.doing,
    comment: 'comment',
    tags: const ['a'],
    epStatus: 3,
    volStatus: 0,
    updatedAt: '2026-01-01',
    private: false,
    subject: BangumiSlimSubject(
      id: 42,
      type: BangumiSubjectType.anime,
      name: 'name',
      nameCn: '名称',
      shortSummary: '',
      date: '2026-01-01',
      images: BangumiImages(
        large: '',
        common: '',
        medium: '',
        small: '',
        grid: '',
      ),
      volumes: 0,
      eps: 12,
      collectionTotal: 10,
      score: 8.0,
      tags: const [],
    ),
  );
}
