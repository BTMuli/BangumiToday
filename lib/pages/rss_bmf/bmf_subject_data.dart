// Project imports:
import '../../core/utils/bangumi_utils.dart';
import '../../models/bangumi/bangumi_data_model.dart';

/// 工作台只复用本地条目数据与排期，不为列表额外请求条目详情。
class BmfSubjectData {
  final String? imageUrl;
  final String? airDate;
  final List<String> names;
  final List<BangumiDataItem> schedules;
  final int? totalEpisodes;

  const BmfSubjectData({
    this.imageUrl,
    this.airDate,
    this.names = const [],
    this.schedules = const [],
    this.totalEpisodes,
  });

  factory BmfSubjectData.fromSources({
    required List<String?> covers,
    required List<String?> dates,
    required List<String?> names,
    List<BangumiDataItem> schedules = const [],
    int? totalEpisodes,
  }) {
    Iterable<String> texts(List<String?> values) =>
        values.whereType<String>().map((value) => value.trim()).where(_hasText);
    return BmfSubjectData(
      imageUrl: texts(covers).firstOrNull,
      airDate: texts(dates).firstOrNull,
      names: texts(names).toSet().toList(),
      schedules: schedules,
      totalEpisodes: totalEpisodes,
    );
  }

  static bool _hasText(String value) => value.trim().isNotEmpty;

  /// 放送时刻按当前排期，话数沿用首页从首播日计算的规则。
  BmfBroadcast? broadcastAt({
    required DateTime at,
    required bool upcoming,
    bool nightMode = false,
  }) {
    BmfBroadcast? result;
    for (var item in schedules) {
      var broadcast = _broadcastFor(
        item,
        at: at,
        upcoming: upcoming,
        nightMode: nightMode,
      );
      if (broadcast == null) continue;
      if (result == null ||
          (upcoming
              ? broadcast.time.isBefore(result.time)
              : broadcast.time.isAfter(result.time))) {
        result = broadcast;
      }
    }
    return result;
  }

  BmfBroadcast? _broadcastFor(
    BangumiDataItem item, {
    required DateTime at,
    required bool upcoming,
    required bool nightMode,
  }) {
    var slot = bangumiAirSlot(
      begin: item.begin,
      broadcast: item.broadcast,
      end: item.end,
      at: at,
      upcoming: upcoming,
      totalEpisodes: totalEpisodes,
      nightMode: nightMode,
    );
    if (slot == null) return null;
    return BmfBroadcast(
      time: slot.time,
      episode: bangumiEpisodeOnAir(
        firstAir: slot.firstAir,
        period: slot.period,
        day: bangumiCalendarStart(at: slot.time, nightMode: nightMode),
        total: totalEpisodes,
      )!,
      upcoming: upcoming,
      nightMode: nightMode,
    );
  }
}

class BmfBroadcast {
  final DateTime time;
  final int episode;
  final bool upcoming;
  final bool nightMode;

  const BmfBroadcast({
    required this.time,
    required this.episode,
    required this.upcoming,
    this.nightMode = false,
  });

  String get label {
    var date = bangumiCalendarDate(at: time, nightMode: nightMode);
    var clock = formatBangumiAirClock(time, nightMode: nightMode);
    return '${upcoming ? '将播' : '已播'} '
        '${date.month}/${date.day} $clock · 第$episode话';
  }

  String get tooltip {
    var date = bangumiCalendarDate(at: time, nightMode: nightMode);
    return '${upcoming ? '即将一话' : '最近一话'}放送：'
        '${date.year}/${date.month}/${date.day} '
        '${formatBangumiAirClock(time, nightMode: nightMode)} · 第$episode话\n'
        '根据本地 BangumiData 排期推算'
        '${nightMode ? '；修仙模式下 24:00–29:59 表示次日凌晨' : '，使用本地时间'}';
  }
}
