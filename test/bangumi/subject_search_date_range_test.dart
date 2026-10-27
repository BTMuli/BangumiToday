// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/pages/subject_search/subject_search_date_range.dart';
import 'package:bangumi_today/pages/subject_search/subject_search_query.dart';

void main() {
  test('year selection sends inclusive calendar-year bounds', () {
    var range = SubjectSearchDateRange.year(2024);
    var query = SubjectSearchQuery(
      dateFrom: range.dateFrom,
      dateTo: range.dateTo,
    );
    expect(query.validationError, isNull);
    expect(query.airdateFilter, ['>=2024-01-01', '<=2024-12-31']);
    expect(range.wholeYear, 2024);
    expect(range.quarterNumber, isNull);
  });

  test('quarter selection ends on the final day of the selected quarter', () {
    var expected = [
      ('2024-01-01', '2024-03-31'),
      ('2024-04-01', '2024-06-30'),
      ('2024-07-01', '2024-09-30'),
      ('2024-10-01', '2024-12-31'),
    ];
    for (var quarter = 1; quarter <= 4; quarter++) {
      var range = SubjectSearchDateRange.quarter(2024, quarter);
      expect(range.dateFrom, expected[quarter - 1].$1);
      expect(range.dateTo, expected[quarter - 1].$2);
      expect(range.quarterNumber, quarter);
      expect(range.wholeYear, isNull);
    }
  });

  test('selecting a start after the end moves the end to the same day', () {
    var range = SubjectSearchDateRange.quarter(
      2024,
      1,
    ).withFrom(DateTime(2024, 4, 5));
    expect(range.dateFrom, '2024-04-05');
    expect(range.dateTo, '2024-04-05');
    expect(
      SubjectSearchQuery(
        dateFrom: range.dateFrom,
        dateTo: range.dateTo,
      ).validationError,
      isNull,
    );
  });

  test('selecting an end before the start moves the start to the same day', () {
    var range = SubjectSearchDateRange.quarter(
      2024,
      2,
    ).withTo(DateTime(2024, 2, 29));
    expect(range.dateFrom, '2024-02-29');
    expect(range.dateTo, '2024-02-29');
    expect(range.quarterNumber, isNull);
    expect(range.wholeYear, isNull);
  });

  test('clearing either endpoint keeps the other as an open-ended filter', () {
    var range = SubjectSearchDateRange.year(2024);
    var before = range.withFrom(null);
    var after = range.withTo(null);
    expect(
      SubjectSearchQuery(
        dateFrom: before.dateFrom,
        dateTo: before.dateTo,
      ).airdateFilter,
      ['<=2024-12-31'],
    );
    expect(
      SubjectSearchQuery(
        dateFrom: after.dateFrom,
        dateTo: after.dateTo,
      ).airdateFilter,
      ['>=2024-01-01'],
    );
    expect(before.withTo(null), const SubjectSearchDateRange());
    expect(range.dateFrom, '2024-01-01');
    expect(range.dateTo, '2024-12-31');
  });

  test(
    'calendar selections discard time without changing the selected day',
    () {
      var range = const SubjectSearchDateRange()
          .withFrom(DateTime.utc(2024, 2, 29, 23, 59))
          .withTo(DateTime(2024, 2, 29, 8, 30));
      expect(range.from, DateTime(2024, 2, 29));
      expect(range.to, DateTime(2024, 2, 29));
      expect(range.dateFrom, '2024-02-29');
      expect(range.dateTo, '2024-02-29');
    },
  );
}
