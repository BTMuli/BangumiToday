// Package imports:
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 获取 BANGUMI_APP_ID
String getBgmAppId() {
  return dotenv.env['BANGUMI_APP_ID'] ?? '';
}

/// 获取 BANGUMI_APP_SECRET
String getBgmAppSecret() {
  return dotenv.env['BANGUMI_APP_SECRET'] ?? '';
}

/// 根据评分获取对应label
String getBangumiRateLabel(double rate) {
  var labels = ['不忍直视', '很差', '差', '较差', '不过不失', '还行', '推荐', '力荐', '神作', '超神作'];
  var index = rate.floor();
  if (index < 0) {
    index = 0;
  } else if (index > 9) {
    index = 9;
  }
  return labels[index];
}
