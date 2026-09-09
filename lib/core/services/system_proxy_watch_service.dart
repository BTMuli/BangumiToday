// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:win32_registry/win32_registry.dart';

// Project imports:
import '../../tools/log_tool.dart';
import '../network/system_proxy.dart';

typedef SystemProxyChanged = Future<void> Function(SystemProxyConfig config);

/// 监听 Windows Internet Settings，并在有效代理配置变化时通知应用。
class SystemProxyWatchService {
  SystemProxyWatchService._();

  static final SystemProxyWatchService instance = SystemProxyWatchService._();

  static const _internetSettingsPath =
      r'Software\Microsoft\Windows\CurrentVersion\Internet Settings';
  static const _debounceDuration = Duration(milliseconds: 400);

  RegistryKey? _key;
  RegistryChangeMonitor? _monitor;
  StreamSubscription<RegistryChangeEvent>? _subscription;
  Timer? _debounceTimer;
  Future<void> _refreshQueue = Future.value();
  SystemProxyChanged? _onChanged;
  SystemProxyConfig? _lastConfig;

  /// 启动注册表事件监听。非 Windows 平台不执行任何操作。
  Future<void> start({required SystemProxyChanged onChanged}) async {
    if (!Platform.isWindows || _monitor != null) return;

    RegistryKey? key;
    RegistryChangeMonitor? monitor;
    StreamSubscription<RegistryChangeEvent>? subscription;
    try {
      key = CURRENT_USER.open(_internetSettingsPath);
      monitor = RegistryChangeMonitor(key);
      subscription = monitor.events.listen(
        (_) => _scheduleRefresh(),
        onError: (Object error, StackTrace stackTrace) {
          BTLogTool.error([
            'Windows 系统代理监听失败',
            error.toString(),
            stackTrace.toString(),
          ]);
        },
      );
      await monitor.start();

      _key = key;
      _monitor = monitor;
      _subscription = subscription;
      _onChanged = onChanged;
      _lastConfig = await WindowsSystemProxy.read();
    } catch (_) {
      await subscription?.cancel();
      if (monitor != null && !monitor.isClosed) await monitor.close();
      key?.close();
      rethrow;
    }
  }

  void _scheduleRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _refreshQueue = _refreshQueue.then((_) => _refresh());
    });
  }

  Future<void> _refresh() async {
    try {
      var config = await WindowsSystemProxy.read();
      if (config == _lastConfig) return;

      _lastConfig = config;
      await _onChanged?.call(config);
      BTLogTool.info('Windows 系统代理配置已实时刷新');
    } catch (error, stackTrace) {
      BTLogTool.error([
        '刷新 Windows 系统代理失败',
        error.toString(),
        stackTrace.toString(),
      ]);
    }
  }

  /// 停止监听并释放注册表和原生事件句柄。
  Future<void> stop() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _subscription?.cancel();
    _subscription = null;

    var monitor = _monitor;
    _monitor = null;
    if (monitor != null && !monitor.isClosed) await monitor.close();

    _key?.close();
    _key = null;
    _onChanged = null;
    _lastConfig = null;
    await _refreshQueue;
  }
}
