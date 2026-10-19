// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Project imports:
import '../../core/network/system_proxy.dart';
import '../../core/services/bangumi_token_service.dart';
import '../../models/app/proxy_settings.dart';
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
  static final Set<BtrClient> _clients = <BtrClient>{};
  static bool _usesSystemProxy = true;
  static const defaultRequestTimeout = Duration(seconds: 45);
  static const _deadlineKey = 'btr.requestDeadline';
  static const _timedOutKey = 'btr.requestTimedOut';

  late Dio _dio;
  bool _disposed = false;
  final Map<
    RequestOptions,
    ({
      CancelToken token,
      Timer timer,
      StreamSubscription<DioException>? cancellation,
    })
  >
  _requests = {};

  /// 构造函数
  BtrClient() {
    _dio = _createDio();
    var interceptor = getInterceptor();
    _dio.interceptors.add(interceptor);
    _addCompletionInterceptor();
    _clients.add(this);
  }

  BtrClient.withHeader() {
    _dio = _createDio();
    var interceptor = getInterceptor();
    _dio.interceptors.add(interceptor);
    _addCompletionInterceptor();
    _clients.add(this);
    Future.microtask(() async {
      var headers = {'User-Agent': await getClientUA()} as Map<String, dynamic>;
      _dio.options.headers.addAll(headers);
    });
  }

  /// 带认证拦截器的客户端（自动处理 token 附加和 401 刷新重试）
  BtrClient.withAuth({BangumiTokenService? tokenService}) {
    _dio = _createDio();
    _dio.options.validateStatus = (status) =>
        status != null && status >= 200 && status < 300;
    _dio.interceptors.add(getInterceptor());
    _dio.interceptors.add(AuthInterceptor(_dio, tokenService: tokenService));
    _addCompletionInterceptor();
    _clients.add(this);
    Future.microtask(() async {
      var headers = {'User-Agent': await getClientUA()} as Map<String, dynamic>;
      _dio.options.headers.addAll(headers);
    });
  }

  /// 获取 Dio 实例
  Dio get dio => _dio;

  /// 取消本客户端的在途请求，保留客户端供后续刷新使用。
  void cancelPendingRequests([String reason = '客户端请求已取消']) {
    for (var request in _requests.values.toList()) {
      request.timer.cancel();
      unawaited(request.cancellation?.cancel());
      if (!request.token.isCancelled) request.token.cancel(reason);
    }
    _requests.clear();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _clients.remove(this);
    cancelPendingRequests('客户端已释放');
    _dio.close(force: true);
  }

  static void disposeAll() {
    for (var client in _clients.toList()) {
      client.dispose();
    }
  }

  /// 获取是否启用应用代理。
  static bool get useSystemProxy => SystemProxyController.enabled;

  /// 更新所选代理配置，并刷新已有客户端的连接池。
  static Future<void> configureSystemProxy(
    bool value, {
    ProxySettings settings = const ProxySettings(),
  }) async {
    var proxy = const SystemProxyConfig.direct();
    if (value) proxy = await settings.resolve();

    _usesSystemProxy = settings.useSystemProxy;
    _applySystemProxy(enabled: value, config: proxy);
  }

  /// 系统代理设置在应用运行期间变化时，刷新已有客户端的连接池。
  static void refreshSystemProxy(SystemProxyConfig proxy) {
    if (!useSystemProxy || !_usesSystemProxy) return;
    _applySystemProxy(enabled: true, config: proxy);
  }

  static void _applySystemProxy({
    required bool enabled,
    required SystemProxyConfig config,
  }) {
    var unchanged =
        SystemProxyController.enabled == enabled &&
        SystemProxyController.config == config;
    SystemProxyController.configure(enabled: enabled, config: config);
    // 启动阶段 main 与 AppStore 会先后下发同一份配置，
    // 无变化时保留现有连接池，避免打断仍在进行中的请求。
    if (unchanged) return;
    _logProxy(enabled: enabled, config: config);
    for (var client in List<BtrClient>.of(_clients)) {
      client._refreshHttpClientAdapter();
    }
  }

  /// 记录实际下发的代理，便于确认请求是否经过代理。
  static void _logProxy({
    required bool enabled,
    required SystemProxyConfig config,
  }) {
    if (!enabled) {
      BTLogTool.info('应用代理已关闭，网络请求直连');
      return;
    }
    var source = _usesSystemProxy ? '系统代理' : '手动代理';
    if (!config.isAvailable) {
      BTLogTool.warn('已启用应用代理（$source），但没有可用的代理地址，请求将直连');
      return;
    }
    BTLogTool.info('已启用应用代理（$source）：${config.describe()}');
  }

  Dio _createDio() {
    var dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    dio.options.validateStatus = (status) => true;
    dio.httpClientAdapter = _createHttpClientAdapter();
    // 放在认证之前，让总时限也覆盖等待 Token 刷新和 401 重试。
    dio.interceptors.add(InterceptorsWrapper(onRequest: _beginRequest));
    return dio;
  }

  void _addCompletionInterceptor() {
    // 认证处理器可能等待刷新或重试，结束后才回收总时限。
    _dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          _finishRequest(response.requestOptions);
          handler.next(response);
        },
        onError: (error, handler) {
          var options = error.requestOptions;
          _finishRequest(options);
          handler.next(
            options.extra[_timedOutKey] == true
                ? error.copyWith(
                    type: DioExceptionType.receiveTimeout,
                    message: '请求超过总时限',
                  )
                : error,
          );
        },
      ),
    );
  }

  void _beginRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    var parent = options.cancelToken;
    var token = CancelToken()..requestOptions = options;
    options.cancelToken = token;
    if (_disposed || parent?.isCancelled == true) {
      token.cancel(_disposed ? '客户端已释放' : parent!.cancelError);
      handler.reject(token.cancelError!);
      return;
    }
    // 单次请求可通过 extra.requestTimeout 覆盖预算；重试沿用原截止时间。
    var timeout =
        options.extra['requestTimeout'] as Duration? ?? defaultRequestTimeout;
    var deadline =
        options.extra[_deadlineKey] as DateTime? ?? DateTime.now().add(timeout);
    options.extra[_deadlineKey] = deadline;
    _finishRequest(options);
    void expire() {
      options.extra[_timedOutKey] = true;
      if (!token.isCancelled) token.cancel('请求超过总时限');
    }

    var remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      expire();
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
          message: '请求超过总时限',
        ),
      );
      return;
    }
    _requests[options] = (
      token: token,
      timer: Timer(remaining, expire),
      // 单次超时只取消自己的请求。完成后解除父 token 监听，避免长期共享
      // token 的订阅刷新保留所有历史 RequestOptions。
      cancellation: parent?.whenCancel.asStream().listen(token.cancel),
    );
    handler.next(options);
  }

  void _finishRequest(RequestOptions options) {
    var request = _requests.remove(options);
    request?.timer.cancel();
    unawaited(request?.cancellation?.cancel());
  }

  IOHttpClientAdapter _createHttpClientAdapter() {
    return IOHttpClientAdapter(
      createHttpClient: () {
        var client = HttpClient()..idleTimeout = const Duration(seconds: 3);
        client.findProxy = SystemProxyController.findProxy;
        return client;
      },
    );
  }

  void _refreshHttpClientAdapter() {
    var oldAdapter = _dio.httpClientAdapter;
    _dio.httpClientAdapter = _createHttpClientAdapter();
    // 优雅关闭旧连接池：已发出的请求继续使用旧连接，仅回收空闲连接。
    // 强制关闭会让启动阶段等正在进行的请求报
    // HttpException: Connection closed before full header was received。
    oldAdapter.close();
  }
}
