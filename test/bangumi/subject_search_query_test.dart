// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/pages/subject_search/subject_search_query.dart';

void main() {
  test(
    'filter-only searches keep inclusive bounds and independent tag kinds',
    () {
      var query = SubjectSearchQuery(
        tags: [' 治愈 ', '治愈', ''],
        metaTags: ['TV', '原创'],
        dateFrom: ' 2024-01-01 ',
        dateTo: '2024-12-31',
        ratingFrom: '7.5',
        rankTo: '500',
        sort: 'score',
      );
      expect(query.isEmpty, isFalse);
      expect(query.validationError, isNull);
      expect(query.tagFilter, ['治愈']);
      expect(query.metaTagFilter, ['TV', '原创']);
      expect(query.airdateFilter, ['>=2024-01-01', '<=2024-12-31']);
      expect(query.ratingFilter, ['>=7.5']);
      expect(query.rankFilter, ['>=1', '<=500']);
      expect(query.description, contains('评分 7.5～不限'));
    },
  );

  test('cleared ranges produce no filter and leave an empty query', () {
    var query = SubjectSearchQuery(keyword: ' ', ratingFrom: ' ');
    expect(query.isEmpty, isTrue);
    expect(query.airdateFilter, isNull);
    expect(query.ratingFilter, isNull);
    expect(query.rankFilter, isNull);
    expect(query.metaTagFilter, isNull);
  });

  test(
    'rank sort excludes unranked subjects, other sorts remain unrestricted',
    () {
      expect(SubjectSearchQuery(sort: 'rank').rankFilter, ['>=1']);
      expect(SubjectSearchQuery(sort: 'score').rankFilter, isNull);
      expect(SubjectSearchQuery(rankFrom: '50', rankTo: '100').rankFilter, [
        '>=50',
        '<=100',
      ]);
    },
  );

  test('unsupported public tag exclusion is reported before search', () {
    expect(SubjectSearchQuery(metaTags: ['-科幻']).validationError, isNotNull);
  });

  test('changing draft selections does not change a pagination snapshot', () {
    var tags = ['原创'];
    var metaTags = ['TV'];
    var types = [BangumiSubjectType.anime];
    var query = SubjectSearchQuery(
      tags: tags,
      metaTags: metaTags,
      types: types,
    );
    tags.clear();
    metaTags.clear();
    types.add(BangumiSubjectType.book);
    expect(query.tags, ['原创']);
    expect(query.metaTags, ['TV']);
    expect(query.types, [BangumiSubjectType.anime]);
    expect(() => query.tags.add('漫画改'), throwsUnsupportedError);
  });

  test('dates reject impossible days, malformed input and reversed ranges', () {
    for (var date in ['2023-02-29', '2024-04-31', '2024-13-01', '2024-1-1']) {
      expect(SubjectSearchQuery(dateFrom: date).validationError, isNotNull);
    }
    expect(SubjectSearchQuery(dateFrom: '2024-02-29').validationError, isNull);
    expect(
      SubjectSearchQuery(
        dateFrom: '2024-12-31',
        dateTo: '2024-01-01',
      ).validationError,
      isNotNull,
    );
  });

  test('scores and ranks reject invalid bounds before sending a request', () {
    for (var score in ['NaN', 'Infinity', '-1', '10.1', '>=8']) {
      expect(SubjectSearchQuery(ratingFrom: score).validationError, isNotNull);
    }
    for (var rank in ['0', '-1', '1.5', 'abc']) {
      expect(SubjectSearchQuery(rankTo: rank).validationError, isNotNull);
    }
    expect(
      SubjectSearchQuery(ratingFrom: '9', ratingTo: '8').validationError,
      isNotNull,
    );
    expect(
      SubjectSearchQuery(rankFrom: '500', rankTo: '1').validationError,
      isNotNull,
    );
    expect(
      SubjectSearchQuery(ratingFrom: '0', ratingTo: '10').validationError,
      isNull,
    );
  });
}
