// Package imports:
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 获取 Interceptor
LogInterceptor getInterceptor() {
  return LogInterceptor(
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
  );
}

/// 获取 UA
Future<String> getClientUA() async {
  var packageInfo = await PackageInfo.fromPlatform();
  var version = '${packageInfo.version}.${packageInfo.buildNumber}';
  var link = 'https://github.com/BTMuli/BangumiToday';
  return 'BTMuli/BangumiToday $version ($link)';
}

/// 请求客户端
class BtrClient {
  late Dio _dio;

  /// 构造函数
  BtrClient() {
    _dio = Dio(BaseOptions());
    _dio.options.validateStatus = (status) => true;
    var interceptor = getInterceptor();
    _dio.interceptors.add(interceptor);
  }

  BtrClient.withHeader() {
    _dio = Dio(BaseOptions());
    _dio.options.validateStatus = (status) => true;
    var interceptor = getInterceptor();
    _dio.interceptors.add(interceptor);
    Future.microtask(() async {
      var headers = {'User-Agent': await getClientUA()} as Map<String, dynamic>;
      _dio.options.headers.addAll(headers);
    });
  }

  /// 获取 Dio 实例
  Dio get dio => _dio;
}
