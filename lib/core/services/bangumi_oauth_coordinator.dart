import 'dart:async';
import 'dart:convert';
import 'dart:math';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Project imports:
import '../../models/app/response.dart';
import '../../request/bangumi/bangumi_oauth.dart';
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
  StreamSubscription<Uri>? _callbackSubscription;
  bool _isAuthorizing = false;

  Future<BTResponse> authorize(BangumiOauthGateway api) async {
    if (_isAuthorizing) {
      return BTResponse.error(code: 409, message: '已有授权流程正在进行', data: null);
    }

    _isAuthorizing = true;
    var state = _stateGenerator();
    var callback = Completer<Uri>();
    _appLinkService.start();
    _callbackSubscription = _appLinkService.stream.listen((uri) {
      if (!_isOAuthCallback(uri) || callback.isCompleted) return;
      callback.complete(uri);
    });

    try {
      await api.openAuthorizePage(state: state);
      var uri = await callback.future.timeout(_callbackTimeout);
      if (uri.queryParameters['state'] != state) {
        return BTResponse.error(code: 400, message: '授权回调校验失败', data: null);
      }
      var code = uri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        return BTResponse.error(code: 400, message: '授权回调中未找到授权码', data: null);
      }
      return await api.getAccessToken(code, state: state);
    } on TimeoutException {
      return BTResponse.error(code: 408, message: '等待授权回调超时', data: null);
    } catch (error) {
      return BTResponse.error(
        code: 666,
        message: '授权流程失败：${error.runtimeType}',
        data: null,
      );
    } finally {
      await _callbackSubscription?.cancel();
      _callbackSubscription = null;
      _isAuthorizing = false;
    }
  }

  bool _isOAuthCallback(Uri uri) {
    return uri.scheme.toLowerCase() == BTAppConstants.urlScheme &&
        uri.host.toLowerCase() == 'oauth';
  }

  static String _createState() {
    var bytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
