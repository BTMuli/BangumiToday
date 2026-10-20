// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/domain/rss/rss_poll_policy.dart';
import 'package:bangumi_today/models/bangumi/bangumi_data_model.dart';

RssPollSchedule _schedule({
  DateTime? first,
  DateTime? anchor,
  DateTime? end,
  String period = 'P7D',
  int? totalEpisodes,
}) {
  var start = first ?? DateTime.utc(2026, 10, 5, 23);
  var item = BangumiDataItem(
    title: '测试番剧',
    titleTranslate: BangumiDataItemTitleTranslate(zh: []),
    type: 'tv',
    lang: 'ja',
    officialSite: '',
    begin: start.toIso8601String(),
    broadcast: 'R/${(anchor ?? start).toUtc().toIso8601String()}/$period',
    end: end?.toUtc().toIso8601String() ?? '',
    comment: null,
    sites: [],
  );
  return (item: item, totalEpisodes: totalEpisodes);
}

void main() {
  const policy = RssPollPolicy();

  test('放送前沿用默认窗口，不提前加速', () {
    var airTime = policy.waitingAirTime(
      now: DateTime.utc(2026, 10, 12, 22, 40),
      schedules: [_schedule()],
    );
    expect(airTime, isNull);
    expect(
      policy.windowFor(airTime: airTime, ttlMinutes: 2),
      const Duration(minutes: 15),
    );
  });

  test('放送后按 TTL 加速，并以 5 分钟兜底', () {
    var airTime = policy.waitingAirTime(
      now: DateTime.utc(2026, 10, 12, 23, 10),
      schedules: [_schedule()],
    );
    expect(airTime, DateTime.utc(2026, 10, 12, 23));
    var windows = {
      0: const Duration(minutes: 5),
      2: const Duration(minutes: 5),
      8: const Duration(minutes: 8),
      30: const Duration(minutes: 15),
    };
    for (var entry in windows.entries) {
      expect(
        policy.windowFor(airTime: airTime, ttlMinutes: entry.key),
        entry.value,
      );
    }
  });

  test('放送后的新条目出现即恢复默认窗口', () {
    var airTime = policy.waitingAirTime(
      now: DateTime.utc(2026, 10, 13, 1),
      schedules: [_schedule()],
    );
    expect(airTime, DateTime.utc(2026, 10, 12, 23));
    expect(
      policy.windowFor(
        airTime: airTime,
        ttlMinutes: 2,
        latestPublishedAt: DateTime.utc(2026, 10, 12, 22, 40),
      ),
      const Duration(minutes: 5),
    );
    expect(
      policy.windowFor(
        airTime: airTime,
        ttlMinutes: 2,
        latestPublishedAt: DateTime.utc(2026, 10, 12, 23, 5),
      ),
      const Duration(minutes: 15),
    );
  });

  test('恰好放送时刻仍处于加速窗口', () {
    var at = DateTime.utc(2026, 10, 12, 23);
    expect(policy.waitingAirTime(now: at, schedules: [_schedule()]), at);
  });

  test('超过放送后 6 小时或排期结束后不再加速', () {
    var after = DateTime.utc(2026, 10, 13, 5, 1);
    expect(policy.waitingAirTime(now: after, schedules: [_schedule()]), isNull);
    var ended = _schedule(end: DateTime.utc(2026, 10, 12, 23));
    expect(policy.waitingAirTime(now: after, schedules: [ended]), isNull);
  });

  test('多档期取放送后最近的有效时刻，放送前不加速', () {
    var old = _schedule(
      first: DateTime.utc(2026, 1, 5, 23),
      end: DateTime.utc(2026, 3, 30, 23),
    );
    var current = _schedule(first: DateTime.utc(2026, 10, 5, 23));
    expect(
      policy.waitingAirTime(
        now: DateTime.utc(2026, 10, 12, 23, 10),
        schedules: [old, current],
      ),
      DateTime.utc(2026, 10, 12, 23),
    );
    expect(
      policy.waitingAirTime(
        now: DateTime.utc(2026, 10, 12, 22, 40),
        schedules: [old, current],
      ),
      isNull,
    );
  });

  test('末播未知但已知总话数时，完结后不再推算加速窗口', () {
    var schedule = _schedule(totalEpisodes: 2);
    var airTime = policy.waitingAirTime(
      now: DateTime.utc(2026, 10, 19, 23, 10),
      schedules: [schedule],
    );
    expect(airTime, isNull);
    expect(
      policy.windowFor(airTime: airTime, ttlMinutes: 2),
      const Duration(minutes: 15),
    );
    expect(
      policy.waitingAirTime(
        now: DateTime.utc(2026, 10, 12, 23, 10),
        schedules: [schedule],
      ),
      DateTime.utc(2026, 10, 12, 23),
    );
  });

  test('共享 feed 的多部番剧分别按各自总话数截断', () {
    expect(
      policy.waitingAirTime(
        now: DateTime.utc(2026, 10, 19, 23, 10),
        schedules: [
          _schedule(totalEpisodes: 2),
          _schedule(first: DateTime.utc(2026, 10, 5, 22), totalEpisodes: 12),
        ],
      ),
      DateTime.utc(2026, 10, 19, 22),
    );
  });
}
