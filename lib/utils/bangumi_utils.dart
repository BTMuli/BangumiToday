/// 获取 BANGUMI_APP_ID
String getBgmAppId() {
  return const String.fromEnvironment('BANGUMI_APP_ID');
}

/// 获取 BANGUMI_APP_SECRET
String getBgmAppSecret() {
  return const String.fromEnvironment('BANGUMI_APP_SECRET');
}

/// 把 BangumiData `begin` 收成 `HH:mm`；无法解析时返回 null。
String? formatBangumiAirClock(String? begin) {
  if (begin == null || begin.isEmpty) return null;
  var time = DateTime.tryParse(begin);
  if (time == null) return null;
  var hour = time.hour.toString().padLeft(2, '0');
  var minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
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
