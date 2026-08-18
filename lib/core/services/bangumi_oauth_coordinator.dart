// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:math';

// Flutter imports:
import 'package:flutter/foundation.dart';

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
  BangumiOAuthCoordinator._({
    AppLinkService? appLinkService,
    String Function()? stateGenerator,
    Duration? callbackTimeout,
  }) : _appLinkService = appLinkService ?? AppLinkService.instance,
       _stateGenerator = stateGenerator ?? _createState,
       _callbackTimeout = callbackTimeout ?? const Duration(minutes: 5);

  /// 仅供测试注入依赖：链接服务、state 生成器和回调超时。
  @visibleForTesting
  BangumiOAuthCoordinator.forTesting({
    AppLinkService? appLinkService,
    String Function()? stateGenerator,
    Duration callbackTimeout = const Duration(minutes: 5),
  }) : _appLinkService = appLinkService ?? AppLinkService.instance,
       _stateGenerator = stateGenerator ?? _createState,
       _callbackTimeout = callbackTimeout;

  static final BangumiOAuthCoordinator instance = BangumiOAuthCoordinator._();

  final AppLinkService _appLinkService;
  final String Function() _stateGenerator;
  final Duration _callbackTimeout;
  StreamSubscription<Uri>? _streamSubscription;
  Completer<Uri>? _callback;
  String? _expectedState;
  Uri? _ignoredOauth;
  bool _isAuthorizing = false;

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
    if (_isAuthorizing) {
      return BTResponse.error(code: 409, message: '已有授权流程正在进行', data: null);
    }

    attach();
    _isAuthorizing = true;
    var state = _stateGenerator();
    _expectedState = state;
    var callback = Completer<Uri>();
    _callback = callback;

    try {
      var latest = _appLinkService.latest;
      if (latest != null && latest != _ignoredOauth) {
        _onAppLink(latest);
      }
      if (!callback.isCompleted) {
        await api.openAuthorizePage(state: state);
      }
      var uri = await callback.future.timeout(_callbackTimeout);
      var code = uri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        return BTResponse.error(code: 400, message: '授权回调中未找到授权码', data: null);
      }
      onProgress?.call('正在换取授权');
      return await api.getAccessToken(code, state: state);
    } on TimeoutException {
      return BTResponse.error(code: 408, message: '等待授权回调超时', data: null);
    } catch (error) {
      return BTResponse.error(code: 666, message: '授权流程失败：$error', data: null);
    } finally {
      _callback = null;
      _expectedState = null;
      _isAuthorizing = false;
    }
  }

  void _onAppLink(Uri uri) {
    if (!_isOAuthCallback(uri)) return;
    var callback = _callback;
    if (callback == null) {
      _ignoredOauth = uri;
      BTLogTool.info('忽略 OAuth 回调：当前没有授权流程');
      return;
    }
    if (callback.isCompleted) return;
    if (uri.queryParameters['state'] != _expectedState) {
      BTLogTool.info('忽略 OAuth 回调：state 不匹配');
      return;
    }
    BTLogTool.info('收到 OAuth 回调：$uri');
    callback.complete(uri);
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
