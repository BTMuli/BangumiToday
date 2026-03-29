import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:bangumi_today/data/datasources/bangumi_remote_data_source.dart';
import 'package:bangumi_today/data/repositories/bangumi_repository_impl.dart';
import 'package:bangumi_today/domain/repositories/bangumi_repository.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/bangumi/request_subject.dart';

import 'bangumi_repository_test.mocks.dart';

@GenerateMocks([BTBangumiRemoteDataSource])
void main() {
  late BTBangumiRepository repository;
  late MockBTBangumiRemoteDataSource mockRemoteDataSource;

  setUp(() {
    mockRemoteDataSource = MockBTBangumiRemoteDataSource();
    repository = BTBangumiRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
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
  });
}
