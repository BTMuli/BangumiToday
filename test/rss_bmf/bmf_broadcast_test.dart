// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/utils/bangumi_utils.dart';
import 'package:bangumi_today/models/bangumi/bangumi_data_model.dart';
import 'package:bangumi_today/models/database/app_bmf_model.dart';
import 'package:bangumi_today/pages/rss_bmf/bmf_filter_model.dart';
import 'package:bangumi_today/pages/rss_bmf/bmf_subject_data.dart';

BangumiDataItem _schedule({
  DateTime? first,
  DateTime? anchor,
  DateTime? end,
  String period = 'P7D',
}) {
  var start = first ?? DateTime(2026, 10, 5, 23);
  return BangumiDataItem(
    title: '测试番剧',
    titleTranslate: BangumiDataItemTitleTranslate(zh: []),
    type: 'tv',
    lang: 'ja',
    officialSite: '',
    begin: start.toUtc().toIso8601String(),
    broadcast: 'R/${(anchor ?? start).toUtc().toIso8601String()}/$period',
    end: end?.toUtc().toIso8601String() ?? '',
    comment: null,
    sites: [],
  );
}

void main() {
  test('同一周内区分最近已播和即将放送，不提前显示下一话已播', () {
    var data = BmfSubjectData(schedules: [_schedule()]);
    var at = DateTime(2026, 10, 12, 22);
    var recent = data.broadcastAt(at: at, upcoming: false)!;
    var next = data.broadcastAt(at: at, upcoming: true)!;

    expect(recent.time.toLocal(), DateTime(2026, 10, 5, 23));
    expect(recent.episode, 1);
    expect(next.time.toLocal(), DateTime(2026, 10, 12, 23));
    expect(next.episode, 2);
    expect(next.label, '将播 10/12 23:00 · 第2话');
    expect(
      data.broadcastAt(at: DateTime(2026, 10, 13), upcoming: false)!.episode,
      2,
    );
  });

  test('首播前无已播记录；恰好放送时刻同时属于最近和即将记录', () {
    var data = BmfSubjectData(schedules: [_schedule()]);
    var before = DateTime(2026, 10, 1);
    expect(data.broadcastAt(at: before, upcoming: false), isNull);
    expect(
      data.broadcastAt(at: before, upcoming: true)!.time.toLocal(),
      DateTime(2026, 10, 5, 23),
    );
    for (var upcoming in [false, true]) {
      var broadcast = data.broadcastAt(
        at: DateTime(2026, 10, 12, 23),
        upcoming: upcoming,
      )!;
      expect(broadcast.time.toLocal(), DateTime(2026, 10, 12, 23));
      expect(broadcast.episode, 2);
    }
  });

  test('已知末播或总话数时停止推算后续排期，并保留最后一话', () {
    var at = DateTime(2026, 12);
    var dataSources = [
      BmfSubjectData(schedules: [_schedule(end: DateTime(2026, 10, 12, 23))]),
      BmfSubjectData(schedules: [_schedule()], totalEpisodes: 2),
    ];
    for (var data in dataSources) {
      expect(data.broadcastAt(at: at, upcoming: true), isNull);
      var recent = data.broadcastAt(at: at, upcoming: false)!;
      expect(recent.time.toLocal(), DateTime(2026, 10, 12, 23));
      expect(recent.episode, 2);
    }
  });

  test('完结状态由末播或总话数确认，不受排序切换影响', () {
    var item = AppBmfModel(subject: 1);
    var lastAir = DateTime(2026, 10, 12, 23);
    var dataSources = [
      BmfSubjectData(schedules: [_schedule(end: lastAir)]),
      BmfSubjectData(schedules: [_schedule()], totalEpisodes: 2),
    ];
    for (var data in dataSources) {
      var model = BmfFilterModel()..resetFilters();
      model.subjectData[item.subject] = data;
      for (var at in [
        DateTime(2026, 10, 1),
        lastAir.subtract(const Duration(minutes: 1)),
        lastAir,
      ]) {
        model.applyFilter([item], now: at);
        expect(model.completedBroadcastFor(item), isNull);
      }
      for (var sort in BmfSortOrder.values) {
        model.sortOrder = sort;
        model.applyFilter([item], now: lastAir.add(const Duration(minutes: 1)));
        var completed = model.completedBroadcastFor(item)!;
        expect(completed.time.toLocal(), lastAir);
        expect(completed.episode, 2);
        expect(completed.tooltip, contains('2026/10/12 23:00 · 第2话'));
      }
      model.applyFilter([item], now: DateTime(2026, 10, 1));
      expect(model.completedBroadcastFor(item), isNull);
    }
  });

  test('信息未知、仍在连载或还有后续档期时不误标完结', () {
    var model = BmfFilterModel()..resetFilters();
    var items = [
      AppBmfModel(subject: 1),
      AppBmfModel(subject: 2),
      AppBmfModel(subject: 3),
    ];
    model.subjectData.addAll({
      2: BmfSubjectData(schedules: [_schedule()]),
      3: BmfSubjectData(
        schedules: [
          _schedule(end: DateTime(2026, 10, 5, 23)),
          _schedule(first: DateTime(2026, 10, 19, 22)),
        ],
      ),
    });
    model.applyFilter(items, now: DateTime(2026, 10, 12));
    for (var item in items) {
      expect(model.completedBroadcastFor(item), isNull);
    }
    expect(model.recentBroadcasts[3], isNotNull);
    expect(model.nextBroadcasts[3]!.time.toLocal(), DateTime(2026, 10, 19, 22));
  });

  test('当季排期决定时刻，首播时间决定话数，支持非每周放送', () {
    var data = BmfSubjectData(
      schedules: [
        _schedule(
          first: DateTime(2026, 9, 28, 23),
          anchor: DateTime(2026, 10, 12, 23),
        ),
      ],
    );
    var next = data.broadcastAt(at: DateTime(2026, 10, 12), upcoming: true)!;
    expect(next.time.toLocal(), DateTime(2026, 10, 12, 23));
    expect(next.episode, 3);

    var daily = BmfSubjectData(schedules: [_schedule(period: 'P1D')]);
    expect(
      daily.broadcastAt(at: DateTime(2026, 10, 7), upcoming: true)!.episode,
      3,
    );
  });

  test('跨年凌晨排期沿用首页的修仙模式日期、时刻和话数', () {
    var first = DateTime(2026, 12, 25, 1, 30);
    var data = BmfSubjectData(schedules: [_schedule(first: first)]);
    var next = data.broadcastAt(
      at: DateTime(2026, 12, 31, 20),
      upcoming: true,
      nightMode: true,
    )!;
    expect(next.time.toLocal(), DateTime(2027, 1, 1, 1, 30));
    expect(next.label, '将播 12/31 25:30 · 第2话');
    expect(next.tooltip, contains('2026/12/31'));
    expect(
      next.episode,
      bangumiEpisodeOnAir(
        firstAir: first,
        period: const Duration(days: 7),
        day: bangumiCalendarStart(at: next.time, nightMode: true),
      ),
    );
  });

  test('多个档期取最近的有效记录，无效时间不伪造排期', () {
    var invalid = _schedule()
      ..begin = 'unknown'
      ..broadcast = 'unknown';
    var data = BmfSubjectData(
      schedules: [
        invalid,
        _schedule(end: DateTime(2026, 10, 5, 23)),
        _schedule(first: DateTime(2026, 10, 8, 22)),
      ],
    );
    var at = DateTime(2026, 10, 12);
    expect(
      data.broadcastAt(at: at, upcoming: false)!.time.toLocal(),
      DateTime(2026, 10, 8, 22),
    );
    expect(
      data.broadcastAt(at: at, upcoming: true)!.time.toLocal(),
      DateTime(2026, 10, 15, 22),
    );
    expect(
      BmfSubjectData(schedules: [invalid]).broadcastAt(at: at, upcoming: true),
      isNull,
    );
  });

  test('两种排序方向相反，未知和没有对应排期的条目置后', () {
    var model = BmfFilterModel()..resetFilters();
    var items = [
      AppBmfModel(subject: 1, title: 'A'),
      AppBmfModel(subject: 2, title: 'B'),
      AppBmfModel(subject: 3, title: 'C'),
    ];
    model.subjectData.addAll({
      1: BmfSubjectData(schedules: [_schedule()]),
      2: BmfSubjectData(
        schedules: [_schedule(first: DateTime(2026, 10, 8, 22))],
      ),
    });
    var at = DateTime(2026, 10, 12);
    model.sortOrder = BmfSortOrder.recentEpisode;
    model.applyFilter(items, now: at);
    expect(model.filteredList.map((item) => item.subject), [2, 1, 3]);
    expect(model.broadcastFor(items.first)!.episode, 1);
    model.sortOrder = BmfSortOrder.nextEpisode;
    model.applyFilter(items, now: at);
    expect(model.filteredList.map((item) => item.subject), [1, 2, 3]);
    expect(model.broadcastFor(items.first)!.episode, 2);

    model.subjectData[1] = BmfSubjectData(
      schedules: [_schedule()],
      totalEpisodes: 1,
    );
    model.applyFilter(items, now: at);
    expect(model.filteredList.map((item) => item.subject), [2, 1, 3]);
    expect(model.broadcastFor(items.first), isNull);
  });
}
