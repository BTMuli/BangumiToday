import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// 请求客户端
class BTRequestClient {
  late Dio _dio;

  /// 构造函数
  BTRequestClient() {
    _dio = Dio(BaseOptions());
    _dio.interceptors.add(LogInterceptor(
      request: false,
      requestBody: false,
      requestHeader: false,
      responseBody: false,
      responseHeader: true,
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
}
