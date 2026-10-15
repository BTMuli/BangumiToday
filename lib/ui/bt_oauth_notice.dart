// Flutter imports:
import 'package:flutter/widgets.dart';

// Project imports:
import '../request/bangumi/bangumi_oauth.dart';
import 'bt_dialog.dart';

/// 登录前的提醒。
///
/// 授权页在系统浏览器的站点域上完成，应用无法代替浏览器登录；浏览器打不开
/// 站点时，流程只会一直等待回调，所以先把这件事讲清楚。
Future<bool> showBangumiLoginNotice(BuildContext context) {
  var host = Uri.parse(BtrBangumiOauth.oauthAuthorizeBaseUrl).host;
  return showConfirmAction(
    context,
    title: '登录 Bangumi',
    content: '将跳转 $host 完成登录授权，请确保能够正常访问。',
    confirmText: '继续登录',
    cancelText: '取消',
  );
}
