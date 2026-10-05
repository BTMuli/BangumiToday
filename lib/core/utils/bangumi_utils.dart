/// 获取 BANGUMI_APP_ID
String getBgmAppId() {
  return const String.fromEnvironment('BANGUMI_APP_ID');
}

/// 获取 BANGUMI_APP_SECRET
String getBgmAppSecret() {
  return const String.fromEnvironment('BANGUMI_APP_SECRET');
}

/// Flutter 只吃编译期 dart-define，不会读取仓库里的 .env。
const String bgmOauthCredentialsMissing =
    'BANGUMI_APP_ID / BANGUMI_APP_SECRET 未注入。'
    '本地请用 --dart-define-from-file=.dart-define.json 启动；'
    '.env 只给发布脚本读取。';

/// 当前编译是否带上了 OAuth 凭据。
bool hasBgmOauthCredentials() {
  return getBgmAppId().isNotEmpty && getBgmAppSecret().isNotEmpty;
}

/// 日本放送时区（JST）相对 UTC 的偏移小时数。
const int bangumiJstOffsetHours = 9;

/// 从 BangumiData `broadcast` 里取出当前放送起点。
///
/// 该字段是 ISO 8601 重复区间，形如 `R/2025-04-29T16:00:00.000Z/P7D`：
/// 起点是当前季度的实际放送时刻（长期番组的 `begin` 是最早的首播时间，
/// 只有 `broadcast` 起点能反映当季排期），周期对日历没有意义。
/// 无法解析时返回 null。
DateTime? parseBangumiBroadcastStart(String? broadcast) {
  if (broadcast == null || broadcast.isEmpty) return null;
  var parts = broadcast.split('/');
  if (parts.length < 3 || parts.first != 'R') return null;
  return DateTime.tryParse(parts[1]);
}

/// 当前的日本放送时刻（JST）。
DateTime bangumiJstNow() {
  return DateTime.now().toUtc().add(
    const Duration(hours: bangumiJstOffsetHours),
  );
}

/// 首页七天窗口的起点：日本放送日当天 0 点，用 UTC 表示。
DateTime bangumiCalendarStart({DateTime? at}) {
  var jst = (at ?? DateTime.now()).toUtc().add(
    const Duration(hours: bangumiJstOffsetHours),
  );
  return DateTime.utc(
    jst.year,
    jst.month,
    jst.day,
  ).subtract(const Duration(hours: bangumiJstOffsetHours));
}

/// 排期是否覆盖 [day] 这个放送日（当天 JST 0 点，用 UTC 表示）。
///
/// 首播与当前排期起点都必须早于当天结束，末播不能早于当天开始。
/// 按整天判断，保留当天已经播出的首话和最后一话。
bool bangumiAirsOnDay({
  required DateTime firstAir,
  required DateTime scheduleStart,
  required DateTime day,
  DateTime? lastAir,
}) {
  var dayEnd = day.add(const Duration(days: 1));
  return firstAir.isBefore(dayEnd) &&
      scheduleStart.isBefore(dayEnd) &&
      (lastAir == null || !lastAir.isBefore(day));
}

/// 放送时刻按日本放送日（JST）归属的星期，1=周一 ... 7=周日。
///
/// 与 bgm.tv 日历的 air_weekday 口径一致：深夜番按日本当天日期归属，
/// 不会因为本地时区回退一天而挪到前一个 Tab。
int bangumiJstWeekday(DateTime time) {
  return time.toUtc().add(const Duration(hours: bangumiJstOffsetHours)).weekday;
}

/// 从 BangumiData `broadcast` 里取出放送周期，如 `P7D`、`P1M`。
///
/// 无法解析时返回 null，调用方按每周放送兜底。
Duration? parseBangumiBroadcastPeriod(String? broadcast) {
  if (broadcast == null || broadcast.isEmpty) return null;
  var parts = broadcast.split('/');
  if (parts.length < 3 || parts.first != 'R') return null;
  var match = RegExp(
    r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$',
  ).firstMatch(parts.last);
  if (match == null) return null;
  var period = match;
  int group(int index) => int.tryParse(period.group(index) ?? '') ?? 0;
  // 月/年按近似天数折算，只用于推算放送话数。
  var days = group(1) * 365 + group(2) * 30 + group(3) * 7 + group(4);
  if (days <= 0) return null;
  return Duration(days: days);
}

/// 该档期在 [day]（当天 0 点）放送的是第几话。
///
/// [firstAir] 是该条目的首播时间（bangumi-data 的 `begin`），**首播当天算第 1 话**：
/// 第 n 话的放送时刻为 `firstAir + (n - 1) * period`，按 [day] 落在哪个周期里取 n。
/// 因此得到的是该条目覆盖的那一档（一季/一季的一部分）里的话数。
///
/// [total] 为该档期已知总话数（bgm 条目数据）：大于 0 时用来兜住因停播、
/// 延期而虚高的推算值。
int? bangumiEpisodeOnAir({
  required DateTime firstAir,
  required Duration period,
  required DateTime day,
  int? total,
}) {
  var seconds = period.inSeconds;
  if (seconds <= 0) return null;
  var offset = day.difference(firstAir).inSeconds;
  var index = offset <= 0 ? 0 : (offset + seconds - 1) ~/ seconds;
  var episode = index + 1;
  if (total != null && total > 0 && episode > total) episode = total;
  return episode < 1 ? null : episode;
}

/// 把放送时刻折算成本地时间的 `HH:mm`；无法解析时返回 null。
String? formatBangumiAirClock(DateTime? time) {
  if (time == null) return null;
  var local = time.toLocal();
  var hour = local.hour.toString().padLeft(2, '0');
  var minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// 把 BangumiData 的 ISO 8601 时间收成 `yyyy-MM-dd`；无法解析时返回空串。
String formatBangumiAirDate(String? time) {
  if (time == null || time.length < 10) return '';
  return time.substring(0, 10);
}

/// 根据评分获取对应label
String getBangumiRateLabel(double rate) {
  var labels = ['不忍直视', '很差', '差', '较差', '不过不失', '还行', '推荐', '力荐', '神作', '超神作'];
  var index = rate.floor() - 1;
  if (index < 0) {
    index = 0;
  } else if (index > 9) {
    index = 9;
  }
  return labels[index];
}
