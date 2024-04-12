import 'package:package_info_plus/package_info_plus.dart';

import '../core/client.dart';

/// 请求客户端
class BtrBangumi extends BTRequestClient {
  /// 构造函数
  BtrBangumi() {
    super.dio.options.headers['User-Agent'] = getClientUA();
  }

  /// 获取 UA
  Future<String> getClientUA() async {
    var packageInfo = await PackageInfo.fromPlatform();
    var version = '${packageInfo.version}.${packageInfo.buildNumber}';
    var link = 'https://github.com/BTMuli/BangumiToday';
    return 'BTMuli/BangumiToday $version ($link)';
  }
}
