import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 获取 BANGUMI_APP_ID
String getBgmAppId() {
  return dotenv.env['BANGUMI_APP_ID'] ?? '';
}

/// 获取 BANGUMI_APP_SECRET
String getBgmAppSecret() {
  return dotenv.env['BANGUMI_APP_SECRET'] ?? '';
}
