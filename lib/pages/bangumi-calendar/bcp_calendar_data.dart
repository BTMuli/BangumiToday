// Project imports:
import '../../models/bangumi/bangumi_data_model.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model_legacy.dart';
import '../../models/bangumi/request_subject.dart';
import '../../utils/bangumi_utils.dart';

/// 首页日历条目：bgm 条目 + 本地时间的放送时刻
class BcpCalendarItem {
  /// bgm 条目，供卡片展示与条目详情跳转
  final BangumiLegacySubjectSmall subject;

  /// 放送时刻（本地时间 `HH:mm`），无法解析时为 null
  final String? airClock;

  /// 该档期当天放送的话数，无法推算时为 null
  final int? episode;

  /// 本地收藏里是否标记为看过
  final bool watched;

  /// 是否在 BMF 订阅列表里
  final bool inBmf;

  /// 构造函数
  const BcpCalendarItem({
    required this.subject,
    required this.airClock,
    required this.episode,
    this.watched = false,
    this.inBmf = false,
  });
}

/// 首页日历数据组装
///
/// 以本地 bangumi-data 为主：条目集合、星期归属与放送时刻全部由它决定；
/// bgm 只作为辅助，按 subject id 补全封面、评分、收藏数等展示字段。
class BcpCalendarData {
  BcpCalendarData._();

  /// 组装一周日历，索引 0=周一 ... 6=周日，按日本放送日归属。
  ///
  /// [items] 为本地 bangumi-data 的在播条目；[siteMeta] 为 bangumi-data
  /// 站点元数据，用于拼条目链接；[enrich] 为 bgm 条目（按 subject id 索引），
  /// 为空时条目只展示 bangumi-data 自带字段，没有封面与评分；
  /// [finishedIds] 为已确认放完的条目，直接不排进日历。
  ///
  /// 缺少 bgm subject id、放送时刻无法解析的条目会被丢弃：它们既无法
  /// 打开条目详情，也无法放进某一天的排期。
  static List<List<BcpCalendarItem>> buildDays({
    required List<BangumiDataItem> items,
    required Map<String, BangumiDataSite> siteMeta,
    required Map<int, BangumiLegacySubjectSmall> enrich,
    Set<int> watchedIds = const {},
    Set<int> bmfIds = const {},
    Set<int> finishedIds = const {},
  }) {
    var days = List.generate(7, (_) => <BcpCalendarItem>[]);
    var dayStarts = _dayStarts();
    var seen = <int>{};
    for (var item in items) {
      var id = subjectIdOf(item);
      if (id == null || finishedIds.contains(id) || !seen.add(id)) continue;
      var anchor =
          parseBangumiBroadcastStart(item.broadcast) ??
          DateTime.tryParse(item.begin);
      if (anchor == null) continue;
      var weekday = bangumiJstWeekday(anchor);
      var bgm = enrich[id];
      var period =
          parseBangumiBroadcastPeriod(item.broadcast) ??
          const Duration(days: 7);
      // 星期与时刻按当季排期，话数从首播日期（放送日期）算起
      var firstAir = DateTime.tryParse(item.begin) ?? anchor;
      days[weekday - 1].add(
        BcpCalendarItem(
          subject: _buildSubject(
            item: item,
            id: id,
            weekday: weekday,
            siteMeta: siteMeta,
            bgm: bgm,
          ),
          airClock: formatBangumiAirClock(anchor),
          episode: bangumiEpisodeOnAir(
            firstAir: firstAir,
            period: period,
            day: dayStarts[weekday] ?? dayStarts.values.first,
            total: _totalEpisodes(bgm),
          ),
          watched: watchedIds.contains(id),
          inBmf: bmfIds.contains(id),
        ),
      );
    }
    for (var day in days) {
      day.sort(compareItem);
    }
    return days;
  }

  /// 每个星期在滚动窗口里的起始时刻（1=周一 ... 7=周日）。
  ///
  /// 窗口与星期归属都按日本放送日算，所以取该星期当天的 JST 0 点；用 UTC
  /// 表示，避免设备时区影响深夜番的话数推算。
  static Map<int, DateTime> _dayStarts() {
    var jst = bangumiJstNow();
    return {
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: DateTime.utc(
          jst.year,
          jst.month,
          jst.day + (weekday - jst.weekday + 7) % 7,
        ).subtract(const Duration(hours: bangumiJstOffsetHours)),
    };
  }

  /// 该档期已知总话数，缺失或为 0 时返回 null。
  static int? _totalEpisodes(BangumiLegacySubjectSmall? bgm) {
    if (bgm == null) return null;
    var total = bgm.epsCount ?? 0;
    if (total <= 0) total = bgm.eps ?? 0;
    return total > 0 ? total : null;
  }

  /// 待确认是否已放完的条目：id -> 放送周期。
  ///
  /// bangumi-data 的 `end` 更新滞后，季度刚完结的作品常常还是空值，于是会一直
  /// 留在日历里。这里先筛出可疑项：排期已经放完 bgm 登记的最后一话，且落后
  /// 不超过 [maxLag] 个周期（落后太多说明该条目长期停播，话数推算不可信，
  /// 不要动它）。筛出来的再用 bgm 章节数据确认，见 `BcpEnricher.confirmFinished`。
  static Map<int, Duration> pendingFinished({
    required List<BangumiDataItem> items,
    required Map<int, BangumiLegacySubjectSmall> enrich,
    int maxLag = 8,
  }) {
    var pending = <int, Duration>{};
    var jst = bangumiJstNow();
    var today = DateTime.utc(
      jst.year,
      jst.month,
      jst.day,
    ).subtract(const Duration(hours: bangumiJstOffsetHours));
    for (var item in items) {
      var id = subjectIdOf(item);
      if (id == null) continue;
      var total = _totalEpisodes(enrich[id]);
      if (total == null) continue;
      var firstAir = DateTime.tryParse(item.begin);
      if (firstAir == null) continue;
      var period =
          parseBangumiBroadcastPeriod(item.broadcast) ??
          const Duration(days: 7);
      var finalAir = firstAir.add(period * (total - 1));
      if (!finalAir.isBefore(today)) continue;
      var lag = today.difference(finalAir).inSeconds / period.inSeconds;
      if (lag > maxLag) continue;
      pending[id] = period;
    }
    return pending;
  }

  /// 用 bgm 日历兜底：本地 bangumi-data 为空（首次安装或尚未同步）时，
  /// 直接用 bgm 的星期分组渲染，保证页面不空白；放送时刻未知。
  static List<List<BcpCalendarItem>> buildDaysFromRemote(
    List<BangumiCalendarRespData> remote, {
    Set<int> watchedIds = const {},
    Set<int> bmfIds = const {},
  }) {
    var days = List.generate(7, (_) => <BcpCalendarItem>[]);
    for (var data in remote) {
      var index = data.weekday.id - 1;
      if (index < 0 || index > 6) continue;
      for (var item in data.items) {
        days[index].add(
          BcpCalendarItem(
            subject: item,
            airClock: null,
            episode: null,
            watched: watchedIds.contains(item.id),
            inBmf: bmfIds.contains(item.id),
          ),
        );
      }
    }
    for (var day in days) {
      day.sort(compareItem);
    }
    return days;
  }

  /// 按放送时刻排序：看过的排该天最后，再看时刻未知的，同刻按 subject id。
  static int compareItem(BcpCalendarItem a, BcpCalendarItem b) {
    if (a.watched != b.watched) return a.watched ? 1 : -1;
    var left = a.airClock;
    var right = b.airClock;
    if (left != right) {
      if (left == null) return 1;
      if (right == null) return -1;
      var result = left.compareTo(right);
      if (result != 0) return result;
    }
    return a.subject.id.compareTo(b.subject.id);
  }

  /// 取条目在 bgm 的 subject id（bangumi-data 的 `bangumi` 站点 id）。
  static int? subjectIdOf(BangumiDataItem item) {
    for (var site in item.sites) {
      if (site.site != 'bangumi') continue;
      var id = int.tryParse(site.id ?? '');
      if (id != null) return id;
    }
    return null;
  }

  /// 把 bangumi-data 条目转成卡片所需的 bgm 条目结构。
  ///
  /// 标题、放送日等以 bangumi-data 为准，只有它没有的展示字段才取 bgm。
  static BangumiLegacySubjectSmall _buildSubject({
    required BangumiDataItem item,
    required int id,
    required int weekday,
    required Map<String, BangumiDataSite> siteMeta,
    required BangumiLegacySubjectSmall? bgm,
  }) {
    var nameCn = _titleTranslate(item.titleTranslate);
    if (nameCn.isEmpty) nameCn = bgm?.nameCn ?? '';
    return BangumiLegacySubjectSmall(
      id: id,
      url: _subjectUrl(siteMeta, id),
      type: BangumiLegacySubjectType.anime,
      name: item.title,
      nameCn: nameCn,
      summary: bgm?.summary ?? '',
      airDate: formatBangumiAirDate(item.begin),
      airWeekday: weekday,
      images: bgm?.images,
      eps: bgm?.eps,
      epsCount: bgm?.epsCount,
      rating: bgm?.rating,
      rank: bgm?.rank,
      collection: bgm?.collection,
    );
  }

  /// 取 bangumi-data 的简体中文标题。
  static String _titleTranslate(BangumiDataItemTitleTranslate translate) {
    for (var title in translate.zh ?? const <String>[]) {
      if (title.isNotEmpty) return title;
    }
    return '';
  }

  /// 按 bangumi-data 站点模板拼条目链接。
  static String _subjectUrl(Map<String, BangumiDataSite> siteMeta, int id) {
    var template = siteMeta['bangumi']?.urlTemplate ?? '';
    if (template.isEmpty) return 'https://bangumi.tv/subject/$id';
    return template.replaceAll('{{id}}', '$id');
  }
}
