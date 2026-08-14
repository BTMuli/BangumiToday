// Package imports:
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Project imports:
import '../../core/services/bangumi_token_service.dart';
import '../../tools/log_tool.dart';
import '../bangumi/bangumi_interceptor.dart';

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
      debugPrint(BTLogTool.sanitize(object));
    },
  );
}

/// 获取 UA
Future<String> getClientUA() async {
  try {
    var packageInfo = await PackageInfo.fromPlatform();
    return 'BangumiToday/${packageInfo.version}';
  } catch (error) {
    BTLogTool.warn('读取应用版本失败，使用默认 User-Agent：$error');
    return 'BangumiToday';
  }
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

  /// 带认证拦截器的客户端（自动处理 token 附加和 401 刷新重试）
  BtrClient.withAuth({BangumiTokenService? tokenService}) {
    _dio = Dio(BaseOptions());
    _dio.options.validateStatus = (status) =>
        status != null && status >= 200 && status < 300;
    _dio.interceptors.add(getInterceptor());
    _dio.interceptors.add(AuthInterceptor(_dio, tokenService: tokenService));
    Future.microtask(() async {
      var headers = {'User-Agent': await getClientUA()} as Map<String, dynamic>;
      _dio.options.headers.addAll(headers);
    });
  }

  /// 获取 Dio 实例
  Dio get dio => _dio;
}
