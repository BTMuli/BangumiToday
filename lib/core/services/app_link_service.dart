import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:app_links/app_links.dart';

/// 应用链接来源抽象，测试时可注入可控的实现。
abstract class AppLinkSource {
  /// 程序运行时的链接流，需要广播模式。
  Stream<Uri> get uriLinkStream;

  /// 冷启动时的初始链接。
  Future<Uri?> getInitialLink();
}

class _AppLinksSource implements AppLinkSource {
  _AppLinksSource(this._appLinks);

  final AppLinks _appLinks;

  @override
  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;

  @override
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();
}

/// 应用链接的唯一系统订阅入口。
///
/// 页面只订阅这个广播流，不直接订阅 [AppLinks.uriLinkStream]，避免页面
/// 重建或反复进入设置页时累积原生监听。
class AppLinkService {
  AppLinkService._({AppLinkSource? source})
    : _source = source ?? _AppLinksSource(AppLinks());

  /// 仅供测试注入可控的链接来源。
  @visibleForTesting
  AppLinkService.forTesting(AppLinkSource source) : _source = source;

  static final AppLinkService instance = AppLinkService._();

  final AppLinkSource _source;
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
    _subscription = _source.uriLinkStream.listen(
      _controller.add,
      onError: (Object error, StackTrace stackTrace) {
        // App-link errors must not terminate the shared stream.
      },
    );
    unawaited(_emitInitialLink());
  }

  Future<void> _emitInitialLink() async {
    try {
      var uri = await _source.getInitialLink();
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
