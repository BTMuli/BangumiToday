// Project imports:
import '../../core/utils/bangumi_utils.dart';
import '../../models/bangumi/bangumi_data_model.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model_legacy.dart';
import '../../models/bangumi/request_subject.dart';

/// 日历补全结果，同时保留展示字段与成人向标记。
typedef BangumiCalendarSubject = ({
  BangumiLegacySubjectSmall subject,
  bool nsfw,
});

/// 首页日历条目：bgm 条目 + 本地时间的放送时刻
class BangumiCalendarItem {
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
  const BangumiCalendarItem({
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
/// bgm 按 subject id 补全展示字段与成人向标记，成人向条目不在首页显示。
class BangumiCalendarData {
  BangumiCalendarData._();

  /// 组装一周日历，索引 0=周一 ... 6=周日，按日本放送日归属。
  ///
  /// [items] 为本地 bangumi-data 在七天窗口内的候选条目；[siteMeta] 为站点
  /// 元数据，用于拼条目链接；[enrich] 为 bgm 条目（按 subject id 索引），
  /// 缺失时仅生成候选条目，确认成人向标记后才能展示；
  /// [finishedIds] 为已确认放完的条目，直接不排进日历。
  ///
  /// 缺少 bgm subject id、放送时刻无法解析的条目会被丢弃：它们既无法
  /// 打开条目详情，也无法放进某一天的排期。
  static List<List<BangumiCalendarItem>> buildDays({
    required List<BangumiDataItem> items,
    required Map<String, BangumiDataSite> siteMeta,
    required Map<int, BangumiCalendarSubject> enrich,
    Set<int> watchedIds = const {},
    Set<int> bmfIds = const {},
    Set<int> finishedIds = const {},
    DateTime? at,
  }) {
    var days = List.generate(7, (_) => <BangumiCalendarItem>[]);
    var dayStarts = _dayStarts(at: at);
    var seen = <int>{};
    for (var item in items) {
      var id = subjectIdOf(item);
      if (id == null || finishedIds.contains(id)) continue;
      var detail = enrich[id];
      if (detail?.nsfw ?? false) continue;
      var anchor =
          parseBangumiBroadcastStart(item.broadcast) ??
          DateTime.tryParse(item.begin);
      if (anchor == null) continue;
      var weekday = bangumiJstWeekday(anchor);
      var day = dayStarts[weekday]!;
      var firstAir = DateTime.tryParse(item.begin) ?? anchor;
      if (!bangumiAirsOnDay(
            firstAir: firstAir,
            scheduleStart: anchor,
            day: day,
            lastAir: DateTime.tryParse(item.end),
          ) ||
          !seen.add(id)) {
        continue;
      }
      var bgm = detail?.subject;
      var period =
          parseBangumiBroadcastPeriod(item.broadcast) ??
          const Duration(days: 7);
      // 星期与时刻按当季排期，话数从首播日期（放送日期）算起
      days[weekday - 1].add(
        BangumiCalendarItem(
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
            day: day,
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
  static Map<int, DateTime> _dayStarts({DateTime? at}) {
    var start = bangumiCalendarStart(at: at);
    var startWeekday = bangumiJstWeekday(start);
    return {
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: start.add(Duration(days: (weekday - startWeekday + 7) % 7)),
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
  /// 不要动它）。筛出来的再用 bgm 章节数据确认，见 `BangumiCalendarEnricher.confirmFinished`。
  ///
  /// [weekday] 只统计这一天要展示的条目（1=周一 ... 7=周日），为空则统计全部；
  /// 首页按分组准备数据时只确认该分组里的条目。
  static Map<int, Duration> pendingFinished({
    required List<BangumiDataItem> items,
    required Map<int, BangumiCalendarSubject> enrich,
    int? weekday,
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
      var detail = enrich[id];
      if (detail?.nsfw ?? false) continue;
      var total = _totalEpisodes(detail?.subject);
      if (total == null) continue;
      var firstAir = DateTime.tryParse(item.begin);
      if (firstAir == null) continue;
      if (weekday != null) {
        var anchor = parseBangumiBroadcastStart(item.broadcast) ?? firstAir;
        if (bangumiJstWeekday(anchor) != weekday) continue;
      }
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
  /// 沿用 bgm 的星期分组；成人向标记仍需由条目详情补全，放送时刻未知。
  static List<List<BangumiCalendarItem>> buildDaysFromRemote(
    List<BangumiCalendarRespData> remote, {
    Map<int, BangumiCalendarSubject> enrich = const {},
    Set<int> watchedIds = const {},
    Set<int> bmfIds = const {},
  }) {
    var days = List.generate(7, (_) => <BangumiCalendarItem>[]);
    for (var data in remote) {
      var index = data.weekday.id - 1;
      if (index < 0 || index > 6) continue;
      for (var item in data.items) {
        var detail = enrich[item.id];
        if (detail?.nsfw ?? false) continue;
        days[index].add(
          BangumiCalendarItem(
            subject: detail?.subject ?? item,
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

  /// 首页仅展示已确认非成人向的条目，未知标记或详情请求失败时也不展示。
  ///
  /// 准备详情时将 [onlyVerified] 设为 false，保留待确认条目以便补全；
  /// 已知成人向条目始终排除，即使它在收藏或订阅列表中。
  static List<BangumiCalendarItem> filterItems(
    List<BangumiCalendarItem> day, {
    required Map<int, BangumiCalendarSubject> enrich,
    Set<int>? collectedIds,
    bool onlyVerified = true,
  }) {
    return [
      for (var item in day)
        if (!(enrich[item.subject.id]?.nsfw ?? onlyVerified) &&
            (collectedIds == null || collectedIds.contains(item.subject.id)))
          item,
    ];
  }

  /// 按放送时刻排序：看过的排该天最后，再看时刻未知的，同刻按 subject id。
  static int compareItem(BangumiCalendarItem a, BangumiCalendarItem b) {
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
