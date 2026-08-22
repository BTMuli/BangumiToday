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

  test('builds the download engine proxy config without losing auth', () {
    var config = SystemProxyConfig.fromWindows(
      enabled: true,
      proxyServer:
          'http=http://127.0.0.1:7890;'
          'https=http://user:secret@proxy.example:7891',
      proxyOverride: '<local>;*.example.com',
    );

    expect(config.toEngineJson(enabled: true), {
      'enabled': true,
      'httpProxy': 'http://127.0.0.1:7890',
      'httpsProxy': 'http://user:secret@proxy.example:7891',
      'bypass': ['<local>', '*.example.com'],
      'peerProxy': {
        'host': 'proxy.example',
        'port': 7891,
        'username': 'user',
        'password': 'secret',
      },
    });
    expect(config.toEngineJson(enabled: false), {'enabled': false});
  });

  test('omits malformed endpoints from the engine proxy config', () {
    var config = const SystemProxyConfig(
      httpProxy: 'http://proxy.example/path',
      httpsProxy: 'not a proxy',
    );

    expect(config.toEngineJson(enabled: true), {
      'enabled': true,
      'bypass': <String>[],
    });
  });
}
