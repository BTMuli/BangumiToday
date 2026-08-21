// Dart imports:
import 'dart:io';

// Project imports:
import '../../tools/log_tool.dart';

/// Windows 当前用户的 Internet 代理配置。
class SystemProxyConfig {
  /// 构造函数。
  const SystemProxyConfig({
    this.httpProxy,
    this.httpsProxy,
    this.bypass = const <String>[],
  });

  /// 直连配置。
  const SystemProxyConfig.direct()
    : httpProxy = null,
      httpsProxy = null,
      bypass = const <String>[];

  /// 根据 Windows Internet 设置创建代理配置。
  factory SystemProxyConfig.fromWindows({
    required bool enabled,
    String? proxyServer,
    String? proxyOverride,
  }) {
    if (!enabled || proxyServer == null || proxyServer.trim().isEmpty) {
      return const SystemProxyConfig.direct();
    }

    String? fallbackProxy;
    String? httpProxy;
    String? httpsProxy;
    for (var part in proxyServer.split(';')) {
      part = part.trim();
      if (part.isEmpty) continue;

      var separator = part.indexOf('=');
      if (separator <= 0) {
        fallbackProxy ??= part;
        continue;
      }

      var scheme = part.substring(0, separator).trim().toLowerCase();
      var proxy = part.substring(separator + 1).trim();
      if (proxy.isEmpty) continue;
      switch (scheme) {
        case 'http':
          httpProxy = proxy;
        case 'https':
          httpsProxy = proxy;
      }
    }

    return SystemProxyConfig(
      httpProxy: httpProxy ?? fallbackProxy,
      httpsProxy: httpsProxy ?? fallbackProxy,
      bypass: _parseBypass(proxyOverride),
    );
  }

  /// HTTP 代理地址。
  final String? httpProxy;

  /// HTTPS 代理地址。
  final String? httpsProxy;

  /// 不经过代理的主机匹配规则。
  final List<String> bypass;

  /// 是否至少配置了一个代理地址。
  bool get isAvailable => httpProxy != null || httpsProxy != null;

  /// 返回 dart:io 使用的 PAC 代理指令。
  String findProxy(Uri uri) {
    if (!uri.isScheme('http') && !uri.isScheme('https')) return 'DIRECT';
    if (_isBypassed(uri.host)) return 'DIRECT';

    var proxy = uri.isScheme('https')
        ? httpsProxy ?? httpProxy
        : httpProxy ?? httpsProxy;
    if (proxy == null || proxy.isEmpty) return 'DIRECT';

    // 复用 dart:io 的解析逻辑，支持 host:port、带协议前缀以及认证信息。
    return HttpClient.findProxyFromEnvironment(
      uri,
      environment: <String, String>{'http_proxy': proxy, 'https_proxy': proxy},
    );
  }

  static List<String> _parseBypass(String? value) {
    if (value == null || value.trim().isEmpty) return const <String>[];
    return value
        .split(';')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  bool _isBypassed(String host) {
    var normalizedHost = host.toLowerCase().replaceFirst(RegExp(r'\.+$'), '');
    for (var pattern in bypass) {
      if (pattern == '<local>' && !normalizedHost.contains('.')) return true;
      if (pattern == '*') return true;

      var regex = RegExp(
        "^${RegExp.escape(pattern).replaceAll(r'\*', '.*')}\$",
      );
      if (regex.hasMatch(normalizedHost)) return true;
    }
    return false;
  }

  @override
  String toString() {
    return 'SystemProxyConfig('
        'httpProxy: $httpProxy, '
        'httpsProxy: $httpsProxy, '
        'bypass: $bypass)';
  }
}

/// 为应用内所有 dart:io HTTP 客户端提供统一的代理回调。
class SystemProxyController {
  static SystemProxyConfig _config = const SystemProxyConfig.direct();
  static bool _enabled = false;
  static _SystemProxyHttpOverrides? _overrides;

  /// 当前是否启用系统代理。
  static bool get enabled => _enabled;

  /// 更新代理配置并安装全局 HTTP 覆盖，使图片缓存等请求也能使用代理。
  static void configure({
    required bool enabled,
    required SystemProxyConfig config,
  }) {
    _installOverrides();
    _config = config;
    _enabled = enabled;
  }

  /// 返回 dart:io 使用的 PAC 代理指令。
  static String findProxy(Uri uri) {
    if (_enabled) return _config.findProxy(uri);
    return HttpClient.findProxyFromEnvironment(uri);
  }

  static void _installOverrides() {
    if (_overrides != null) return;
    var overrides = _SystemProxyHttpOverrides(HttpOverrides.current);
    _overrides = overrides;
    HttpOverrides.global = overrides;
  }
}

class _SystemProxyHttpOverrides extends HttpOverrides {
  _SystemProxyHttpOverrides(this._parent);

  final HttpOverrides? _parent;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    var client =
        _parent?.createHttpClient(context) ?? super.createHttpClient(context);
    client.findProxy = SystemProxyController.findProxy;
    return client;
  }
}

/// 读取 Windows 当前用户的系统代理。
class WindowsSystemProxy {
  WindowsSystemProxy._();

  static const _internetSettingsKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  /// 读取当前系统代理设置。
  static Future<SystemProxyConfig> read() async {
    if (!Platform.isWindows) return const SystemProxyConfig.direct();

    try {
      var values = await _readRegistryValues();
      var enabled = _parseDword(values['ProxyEnable']) == 1;
      var config = SystemProxyConfig.fromWindows(
        enabled: enabled,
        proxyServer: values['ProxyServer'],
        proxyOverride: values['ProxyOverride'],
      );
      if (enabled && !config.isAvailable) {
        BTLogTool.warn('Windows system proxy is enabled but no proxy server');
      }
      if (!enabled && (values['AutoConfigURL']?.isNotEmpty ?? false)) {
        BTLogTool.warn(
          'Windows system proxy uses an auto-config script, which is not '
          'supported',
        );
      }
      return config;
    } catch (error) {
      BTLogTool.warn('读取 Windows 系统代理失败：$error');
      return const SystemProxyConfig.direct();
    }
  }

  static Future<Map<String, String>> _readRegistryValues() async {
    var result = await Process.run('reg.exe', [
      'query',
      _internetSettingsKey,
    ], runInShell: false);
    if (result.exitCode != 0) {
      throw StateError('reg.exe exited with code ${result.exitCode}');
    }

    var values = <String, String>{};
    var valuePattern = RegExp(r'^\s+(\S+)\s+REG_\S+\s+(.+?)\s*$');
    for (var line in result.stdout.toString().split(RegExp(r'\r?\n'))) {
      var match = valuePattern.firstMatch(line);
      if (match == null) continue;
      values[match.group(1)!] = match.group(2)!.trim();
    }
    return values;
  }

  static int? _parseDword(String? value) {
    if (value == null) return null;
    value = value.trim().toLowerCase();
    if (value.startsWith('0x')) {
      return int.tryParse(value.substring(2), radix: 16);
    }
    return int.tryParse(value);
  }
}
