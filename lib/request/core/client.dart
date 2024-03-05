import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 请求客户端
class BTRequestClient {
  late Dio _dio;

  /// 构造函数
  BTRequestClient() {
    _dio = Dio(BaseOptions());
    _dio.options.headers['User-Agent'] = getClientUA();
    _dio.interceptors.add(LogInterceptor(
      request: false,
      requestBody: false,
      requestHeader: false,
      responseBody: false,
      responseHeader: false,
      error: true,
      logPrint: (object) {
        if (object is String) {
          debugPrint(object);
        } else {
          debugPrint(object.toString());
        }
      },
    ));
  }

  /// 获取 Dio 实例
  Dio get dio => _dio;

  /// 获取 UA
  Future<String> getClientUA() async {
    var packageInfo = await PackageInfo.fromPlatform();
    var version = '${packageInfo.version}.${packageInfo.buildNumber}';
    var link = 'https://github.com/BTMuli/BangumiToday';
    return 'BTMuli/BangumiToday $version ($link)';
  }
}
