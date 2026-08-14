// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../../core/services/bangumi_token_service.dart';
import '../../tools/log_tool.dart';

/// Token 认证拦截器
/// 自动处理：请求附加 token、401 时自动刷新并重试、防止并发重复刷新
class AuthInterceptor extends Interceptor {
  /// Dio 实例，用于重试请求
  final Dio _dio;

  /// Token 刷新协调器。所有 Dio 客户端共享应用级 single-flight。
  final BangumiTokenService _tokenService;

  /// 构造函数
  AuthInterceptor(this._dio, {BangumiTokenService? tokenService})
    : _tokenService = tokenService ?? BangumiTokenService.instance;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      var token = options.extra['authRetried'] == true
          ? _tokenService.currentAccessToken
          : await _tokenService.accessTokenForRequest();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 只处理 401 未授权
    if (err.response?.statusCode != 401 ||
        err.type == DioExceptionType.cancel ||
        err.requestOptions.extra['authRetried'] == true) {
      handler.next(err);
      return;
    }

    var requestToken = err.requestOptions.headers['Authorization']?.toString();
    var currentToken = _tokenService.currentAccessToken;
    var tokenAlreadyRotated =
        requestToken != null &&
        currentToken != null &&
        currentToken.isNotEmpty &&
        requestToken != 'Bearer $currentToken';
    var result = tokenAlreadyRotated
        ? BangumiTokenRefreshResult.refreshed
        : await _tokenService.ensureFresh(force: true);
    if (result != BangumiTokenRefreshResult.refreshed) {
      BTLogTool.warn('Token 刷新失败，重试终止：$result');
      handler.next(err);
      return;
    }

    await _retry(err, handler);
  }

  /// 用新 token 重试原请求
  Future<void> _retry(DioException err, ErrorInterceptorHandler handler) async {
    var requestOptions = err.requestOptions;
    requestOptions.extra['authRetried'] = true;

    // 更新 header 为最新 token
    var token = _tokenService.currentAccessToken;
    if (token != null && token.isNotEmpty) {
      requestOptions.headers['Authorization'] = 'Bearer $token';
    }

    try {
      var response = await _dio.fetch(requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
