// Dart imports:
import 'dart:async';

// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../../store/bgm_user_hive.dart';
import '../../tools/log_tool.dart';

/// Token 认证拦截器
/// 自动处理：请求附加 token、401 时自动刷新并重试、防止并发重复刷新
class AuthInterceptor extends Interceptor {
  /// Dio 实例，用于重试请求
  final Dio _dio;

  /// 刷新锁，防止多个 401 并发时重复刷新 token
  Completer<void>? _refreshLock;

  /// 是否正在刷新中
  bool get _isRefreshing => _refreshLock != null;

  /// 构造函数
  AuthInterceptor(this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    var token = BgmUserHive().tokenAC;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 只处理 401 未授权
    if (err.response?.statusCode != 401 ||
        err.type == DioExceptionType.cancel) {
      handler.next(err);
      return;
    }

    // 如果已经在刷新，等待刷新完成
    if (_isRefreshing) {
      try {
        await _refreshLock!.future;
      } catch (_) {
        handler.next(err);
        return;
      }
      // 刷新完成后用新 token 重试
      await _retry(err, handler);
      return;
    }

    // 开始刷新
    _refreshLock = Completer<void>();
    try {
      var success = await _doRefreshToken();
      _refreshLock!.complete();

      if (success) {
        await _retry(err, handler);
      } else {
        BTLogTool.warn('Token 刷新失败，重试终止');
        handler.next(err);
      }
    } catch (e) {
      _refreshLock!.completeError(e);
      BTLogTool.error('Token 刷新异常: $e');
      handler.next(err);
    } finally {
      _refreshLock = null;
    }
  }

  /// 执行 token 刷新
  Future<bool> _doRefreshToken() async {
    var hive = BgmUserHive();
    if (hive.tokenRF == null || hive.tokenRF!.isEmpty) {
      BTLogTool.warn('无 refreshToken，无法刷新');
      return false;
    }
    var result = await hive.refreshAuth(force: true);
    return result == true;
  }

  /// 用新 token 重试原请求
  Future<void> _retry(DioException err, ErrorInterceptorHandler handler) async {
    var requestOptions = err.requestOptions;

    // 更新 header 为最新 token
    var token = BgmUserHive().tokenAC;
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
