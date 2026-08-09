import 'dart:async';

import 'package:app_links/app_links.dart';

/// 应用链接的唯一系统订阅入口。
///
/// 页面只订阅这个广播流，不直接订阅 [AppLinks.uriLinkStream]，避免页面
/// 重建或反复进入设置页时累积原生监听。
class AppLinkService {
  AppLinkService._();

  static final AppLinkService instance = AppLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamController<Uri> _controller = StreamController<Uri>.broadcast();
  StreamSubscription<Uri>? _subscription;
  bool _started = false;

  Stream<Uri> get stream {
    start();
    return _controller.stream;
  }

  void start() {
    if (_started) return;
    if (_controller.isClosed) {
      _controller = StreamController<Uri>.broadcast();
    }
    _started = true;
    _subscription = _appLinks.uriLinkStream.listen(
      _controller.add,
      onError: (Object error, StackTrace stackTrace) {
        // App-link errors must not terminate the shared stream.
      },
    );
    unawaited(_emitInitialLink());
  }

  Future<void> _emitInitialLink() async {
    try {
      var uri = await _appLinks.getInitialLink();
      if (uri != null && !_controller.isClosed) _controller.add(uri);
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
