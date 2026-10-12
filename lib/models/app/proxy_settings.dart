// Dart imports:
import 'dart:io';

// Project imports:
import '../../core/network/system_proxy.dart';

/// 应用和下载引擎共用的代理来源；是否启用由各自的开关决定。
class ProxySettings {
  const ProxySettings({
    this.useSystemProxy = true,
    this.host = '127.0.0.1',
    this.port = 7890,
  });

  factory ProxySettings.manual({required String host, required String port}) {
    var hostError = validateHost(host);
    if (hostError != null) throw FormatException(hostError);
    var portError = validatePort(port);
    if (portError != null) throw FormatException(portError);
    return ProxySettings(
      useSystemProxy: false,
      host: _normalizeHost(host),
      port: int.parse(port.trim()),
    );
  }

  factory ProxySettings.fromJson(Map<String, dynamic> json) {
    var manual = ProxySettings.manual(
      host: json['host'] as String,
      port: (json['port'] as int).toString(),
    );
    return ProxySettings(
      useSystemProxy: json['useSystemProxy'] as bool,
      host: manual.host,
      port: manual.port,
    );
  }

  final bool useSystemProxy;
  final String host;
  final int port;

  Map<String, dynamic> toJson() => {
    'useSystemProxy': useSystemProxy,
    'host': host,
    'port': port,
  };

  static String _normalizeHost(String value) {
    var host = value.trim().toLowerCase();
    if (host.startsWith('[') && host.endsWith(']')) {
      host = host.substring(1, host.length - 1);
    }
    return host;
  }

  static String? validateHost(String? value) {
    var host = _normalizeHost(value ?? '');
    if (host.isEmpty) return '请输入代理地址';
    if (InternetAddress.tryParse(host) != null) return null;
    var label = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
    if (host.length > 253 ||
        RegExp(r'^[0-9.]+$').hasMatch(host) ||
        (value?.trim().startsWith('[') ?? false) ||
        !host.split('.').every(label.hasMatch)) {
      return '请输入 IP 或主机名，不含协议、路径和端口';
    }
    return null;
  }

  static String? validatePort(String? value) {
    var text = value?.trim() ?? '';
    var port = int.tryParse(text);
    if (!RegExp(r'^\d+$').hasMatch(text) ||
        port == null ||
        port < 1 ||
        port > 65535) {
      return '请输入 1–65535 的端口';
    }
    return null;
  }

  /// 读取系统代理，或为 HTTP/HTTPS 请求使用同一个手动 HTTP 代理。
  Future<SystemProxyConfig> resolve() async {
    if (useSystemProxy) return WindowsSystemProxy.read();
    var manual = ProxySettings.manual(host: host, port: port.toString());
    var address = manual.host.contains(':') ? '[${manual.host}]' : manual.host;
    // Uri 会省略 HTTP 的 80 端口，而 dart:io 对无端口的代理默认使用 1080。
    var endpoint = 'http://$address:${manual.port}';
    return SystemProxyConfig(httpProxy: endpoint, httpsProxy: endpoint);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProxySettings &&
          useSystemProxy == other.useSystemProxy &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => Object.hash(useSystemProxy, host, port);
}
