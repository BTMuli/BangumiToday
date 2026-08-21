// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/network/system_proxy.dart';

void main() {
  test('parses Windows HTTP and HTTPS proxy settings', () {
    var config = SystemProxyConfig.fromWindows(
      enabled: true,
      proxyServer: 'http=127.0.0.1:7890;https=127.0.0.1:7891',
    );

    expect(
      config.findProxy(Uri.parse('http://example.com')),
      'PROXY 127.0.0.1:7890',
    );
    expect(
      config.findProxy(Uri.parse('https://example.com')),
      'PROXY 127.0.0.1:7891',
    );
  });

  test('uses bypass rules from Windows proxy settings', () {
    var config = SystemProxyConfig.fromWindows(
      enabled: true,
      proxyServer: '127.0.0.1:7890',
      proxyOverride: '<local>;*.example.com',
    );

    expect(config.findProxy(Uri.parse('http://localhost')), 'DIRECT');
    expect(config.findProxy(Uri.parse('http://api.example.com')), 'DIRECT');
    expect(
      config.findProxy(Uri.parse('http://example.net')),
      'PROXY 127.0.0.1:7890',
    );
  });

  test('disabled Windows proxy falls back to a direct connection', () {
    var config = SystemProxyConfig.fromWindows(
      enabled: false,
      proxyServer: '127.0.0.1:7890',
    );

    expect(config.findProxy(Uri.parse('https://example.com')), 'DIRECT');
  });

  test('controller exposes the configured proxy directive', () {
    var config = SystemProxyConfig.fromWindows(
      enabled: true,
      proxyServer: '127.0.0.1:7890',
    );
    SystemProxyController.configure(enabled: true, config: config);

    try {
      expect(
        SystemProxyController.findProxy(Uri.parse('https://example.com')),
        'PROXY 127.0.0.1:7890',
      );
    } finally {
      SystemProxyController.configure(
        enabled: false,
        config: const SystemProxyConfig.direct(),
      );
    }
  });
}
