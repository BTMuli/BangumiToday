// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/models/bangumi/bangumi_data_model.dart';
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model_legacy.dart';
import 'package:bangumi_today/pages/bangumi_calendar/bangumi_calendar_data.dart';

BangumiDataItem _item({
  required int id,
  required DateTime begin,
  DateTime? broadcast,
  String end = '',
  String period = 'P7D',
}) {
  var start = broadcast ?? begin;
  return BangumiDataItem(
    title: 'subject-$id',
    titleTranslate: BangumiDataItemTitleTranslate(zh: ['条目$id']),
    type: 'tv',
    lang: 'ja',
    officialSite: '',
    begin: begin.toUtc().toIso8601String(),
    broadcast: 'R/${start.toUtc().toIso8601String()}/$period',
    end: end,
    comment: null,
    sites: [
      BangumiDataItemSite(
        site: 'bangumi',
        id: '$id',
        begin: null,
        broadcast: null,
      ),
    ],
  );
}

BangumiCalendarSubject _enrich(int id, {required int total}) {
  return (
    nsfw: false,
    subject: BangumiLegacySubjectSmall(
      id: id,
      url: 'https://bangumi.tv/subject/$id',
      type: BangumiLegacySubjectType.anime,
      name: 'subject-$id',
      nameCn: '条目$id',
      summary: '',
      airDate: '',
      airWeekday: 1,
      images: null,
      eps: total,
      epsCount: total,
      rating: null,
      rank: null,
      collection: null,
    ),
  );
}

void main() {
  test('end 为空但总话数已放完时，不再进入本周日历', () {
    // 2026-07-07 周二首播，12 话每周，末播约 9/22；观察日 11/5 应已结束。
    var begin = DateTime.utc(2026, 7, 7, 13);
    var days = BangumiCalendarData.buildDays(
      items: [_item(id: 1001, begin: begin)],
      siteMeta: const {},
      enrich: {1001: _enrich(1001, total: 12)},
      at: DateTime(2026, 11, 5, 15),
    );

    expect(days.every((day) => day.isEmpty), isTrue);
  });

  test('当季仍在放送时保留在对应星期', () {
    var begin = DateTime.utc(2026, 10, 7, 13);
    var days = BangumiCalendarData.buildDays(
      items: [_item(id: 1002, begin: begin)],
      siteMeta: const {},
      enrich: {1002: _enrich(1002, total: 12)},
      at: DateTime(2026, 11, 5, 15),
    );

    expect(
      days.expand((day) => day).map((item) => item.subject.id),
      contains(1002),
    );
  });

  test('长期番按 broadcast 锚点推末播，不被多年前的 begin 误杀', () {
    var begin = DateTime.utc(2020, 1, 7, 13);
    // 本季新锚点：总话数按当季续算，避免 begin 把末播推到多年前
    var season = DateTime.utc(2026, 10, 7, 13);
    var days = BangumiCalendarData.buildDays(
      items: [_item(id: 1003, begin: begin, broadcast: season)],
      siteMeta: const {},
      enrich: {1003: _enrich(1003, total: 360)},
      at: DateTime(2026, 11, 5, 15),
    );

    expect(
      days.expand((day) => day).map((item) => item.subject.id),
      contains(1003),
    );
  });
}
