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

/// 修仙模式的本地放送日换日时刻。
const int bangumiNightModeStartHour = 6;

/// 首页放送日按系统本地时区计算，修仙模式下凌晨 6 点前归属前一日。
/// 使用日历日期构造，避免夏令时切换日按 24 小时累加导致日期偏移。
DateTime bangumiCalendarDate({
  DateTime? at,
  int offset = 0,
  bool nightMode = false,
}) {
  var local = (at ?? DateTime.now()).toLocal();
  var previousDay = nightMode && local.hour < bangumiNightModeStartHour;
  return DateTime(
    local.year,
    local.month,
    local.day + offset - (previousDay ? 1 : 0),
  );
}

/// 首页窗口的放送日起点，用 UTC 表示；修仙模式为本地 6 点，否则为 0 点。
DateTime bangumiCalendarStart({
  DateTime? at,
  int offset = 0,
  bool nightMode = false,
}) {
  var date = bangumiCalendarDate(at: at, offset: offset, nightMode: nightMode);
  return DateTime(
    date.year,
    date.month,
    date.day,
    nightMode ? bangumiNightModeStartHour : 0,
  ).toUtc();
}

/// 排期是否覆盖 [day] 这个本地放送日（当天的 0 点或修仙模式下的 6 点）。
///
/// 首播与当前排期起点都必须早于当天结束，末播不能早于当天开始。
/// 按整天判断，保留当天已经播出的首话和最后一话。
bool bangumiAirsOnDay({
  required DateTime firstAir,
  required DateTime scheduleStart,
  required DateTime day,
  DateTime? lastAir,
}) {
  var local = day.toLocal();
  var dayEnd = DateTime(local.year, local.month, local.day + 1, local.hour);
  return firstAir.isBefore(dayEnd) &&
      scheduleStart.isBefore(dayEnd) &&
      (lastAir == null || !lastAir.isBefore(day));
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

/// 该档期在 [day]（放送日起点）放送的是第几话。
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

/// 把放送时刻折算成本地时间；修仙模式将次日凌晨显示为 24:00–29:59。
String? formatBangumiAirClock(DateTime? time, {bool nightMode = false}) {
  if (time == null) return null;
  var local = time.toLocal();
  var extendedHour =
      local.hour +
      (nightMode && local.hour < bangumiNightModeStartHour ? 24 : 0);
  var hour = extendedHour.toString().padLeft(2, '0');
  var minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// 把 BangumiData 的 ISO 8601 时间折算成本地日期；无法解析时返回空串。
String formatBangumiAirDate(String? time) {
  var local = time == null ? null : DateTime.tryParse(time)?.toLocal();
  if (local == null) return '';
  var year = local.year.toString().padLeft(4, '0');
  var month = local.month.toString().padLeft(2, '0');
  var day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
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
