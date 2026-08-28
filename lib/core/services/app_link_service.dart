// Dart imports:
import 'dart:async';

// Package imports:
import 'package:app_links/app_links.dart';

// Project imports:
import '../../tools/log_tool.dart';

/// 应用链接的唯一系统订阅入口。
///
/// 页面只订阅这个广播流，不直接订阅 [AppLinks.uriLinkStream]，避免页面
/// 重建或反复进入设置页时累积原生监听。
class AppLinkService {
  AppLinkService._() : _source = AppLinks();

  static final AppLinkService instance = AppLinkService._();

  final AppLinks _source;
  StreamController<Uri> _controller = StreamController<Uri>.broadcast();
  StreamSubscription<Uri>? _subscription;
  bool _started = false;
  Uri? _latest;

  Stream<Uri> get stream {
    start();
    return _controller.stream;
  }

  /// 最近一次收到的应用链接。授权流程开始时可回放 OAuth 回调。
  Uri? get latest => _latest;

  void start() {
    if (_started) return;
    if (_controller.isClosed) {
      _controller = StreamController<Uri>.broadcast();
    }
    _started = true;
    _subscription = _source.uriLinkStream.listen(
      _emitLink,
      onError: (Object error, StackTrace stackTrace) {
        // App-link errors must not terminate the shared stream.
      },
    );
    unawaited(_emitInitialLink());
  }

  void _emitLink(Uri uri) {
    _latest = uri;
    BTLogTool.info('收到应用链接：$uri');
    if (!_controller.isClosed) _controller.add(uri);
  }

  Future<void> _emitInitialLink() async {
    try {
      var uri = await _source.getInitialLink();
      if (uri != null) _emitLink(uri);
    } catch (_) {
      // A missing initial link is a normal startup condition.
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
    await _controller.close();
  }
}
