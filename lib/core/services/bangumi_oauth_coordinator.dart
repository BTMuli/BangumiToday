// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:math';

// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../../models/app/response.dart';
import '../../request/bangumi/bangumi_oauth.dart';
import '../../tools/log_tool.dart';
import '../constants/app_constants.dart';
import 'app_link_service.dart';

/// Bangumi OAuth 流程协调器。
///
/// OAuth 回调是应用级事件，不能由页面各自监听。协调器保证同一时间
/// 只有一个授权流程，并在回调中校验一次性 state。
class BangumiOAuthCoordinator {
  BangumiOAuthCoordinator._()
    : _appLinkService = AppLinkService.instance,
      _stateGenerator = _createState,
      _callbackTimeout = const Duration(minutes: 5);

  static final BangumiOAuthCoordinator instance = BangumiOAuthCoordinator._();

  final AppLinkService _appLinkService;
  final String Function() _stateGenerator;
  final Duration _callbackTimeout;
  StreamSubscription<Uri>? _streamSubscription;
  _BangumiOAuthAttempt? _attempt;
  Uri? _ignoredOauth;

  bool get isAuthorizing => _attempt != null;

  /// 立即释放当前流程，迟到的回调和请求结果不能影响下一次授权。
  void cancel() {
    var attempt = _attempt;
    if (attempt == null) return;
    _attempt = null;
    attempt.cancel();
  }

  /// 全程订阅应用链接。OAuth 回调若在未登录时到达，会打忽略日志而不是静默丢弃。
  void attach() {
    if (_streamSubscription != null) return;
    _appLinkService.start();
    _streamSubscription = _appLinkService.stream.listen(_onAppLink);
  }

  Future<BTResponse> authorize(
    BangumiOauthGateway api, {
    void Function(String text)? onProgress,
  }) async {
    if (isAuthorizing) {
      return BTResponse.error(code: 409, message: '已有授权流程正在进行', data: null);
    }

    attach();
    var attempt = _BangumiOAuthAttempt(_stateGenerator());
    _attempt = attempt;
    var waitingForCallback = true;

    try {
      var latest = _appLinkService.latest;
      if (latest != null && latest != _ignoredOauth) {
        _onAppLink(latest);
      }
      var uri = await attempt
          .waitFor(_waitForCallback(api, attempt, onProgress))
          .timeout(_callbackTimeout);
      if (uri == null) throw const _BangumiOAuthCancelled();
      var code = uri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        return BTResponse.error(code: 400, message: '授权回调中未找到授权码', data: null);
      }
      waitingForCallback = false;
      onProgress?.call('正在换取授权');
      return await attempt
          .waitFor(
            api.getAccessToken(
              code,
              state: attempt.state,
              cancelToken: attempt.cancelToken,
            ),
          )
          .timeout(const Duration(seconds: 30));
    } on _BangumiOAuthCancelled {
      return BTResponse.error(code: 499, message: '已取消授权', data: null);
    } on TimeoutException {
      return BTResponse.error(
        code: 408,
        message: waitingForCallback ? '等待授权回调超时，请重新登录' : '换取授权超时，请重新登录',
        data: null,
      );
    } catch (error) {
      return BTResponse.error(code: 666, message: '授权流程失败：$error', data: null);
    } finally {
      attempt.cancel();
      if (identical(_attempt, attempt)) _attempt = null;
    }
  }

  Future<Uri?> _waitForCallback(
    BangumiOauthGateway api,
    _BangumiOAuthAttempt attempt,
    void Function(String text)? onProgress,
  ) async {
    if (!attempt.callback.isCompleted) {
      await api.openAuthorizePage(state: attempt.state);
    }
    if (attempt.cancelToken.isCancelled) {
      throw const _BangumiOAuthCancelled();
    }
    if (!attempt.callback.isCompleted) {
      onProgress?.call('请在浏览器中完成授权。若页面卡住，可取消后重新登录。');
    }
    return attempt.callback.future;
  }

  void _onAppLink(Uri uri) {
    if (!_isOAuthCallback(uri)) return;
    var attempt = _attempt;
    if (attempt == null) {
      _ignoredOauth = uri;
      BTLogTool.info('忽略 OAuth 回调：当前没有授权流程');
      return;
    }
    if (attempt.callback.isCompleted) return;
    if (uri.queryParameters['state'] != attempt.state) {
      BTLogTool.info('忽略 OAuth 回调：state 不匹配');
      return;
    }
    BTLogTool.info('收到 OAuth 回调：$uri');
    attempt.callback.complete(uri);
  }

  bool _isOAuthCallback(Uri uri) {
    if (uri.scheme.toLowerCase() != BTAppConstants.urlScheme) return false;
    if (uri.host.toLowerCase() == 'oauth') return true;
    var segments = uri.pathSegments
        .map((segment) => segment.toLowerCase())
        .toList();
    return segments.isNotEmpty && segments.first == 'oauth';
  }

  static String _createState() {
    var bytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

class _BangumiOAuthAttempt {
  _BangumiOAuthAttempt(this.state);

  final String state;
  final Completer<Uri?> callback = Completer<Uri?>();
  final CancelToken cancelToken = CancelToken();

  Future<T> waitFor<T>(Future<T> future) async {
    var result = await Future.any<T>([
      future,
      cancelToken.whenCancel.then<T>((_) {
        throw const _BangumiOAuthCancelled();
      }),
    ]);
    if (cancelToken.isCancelled) throw const _BangumiOAuthCancelled();
    return result;
  }

  void cancel() {
    if (!cancelToken.isCancelled) cancelToken.cancel('授权流程已结束');
    if (!callback.isCompleted) callback.complete(null);
  }
}

class _BangumiOAuthCancelled implements Exception {
  const _BangumiOAuthCancelled();
}
