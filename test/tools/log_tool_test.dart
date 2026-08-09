import 'package:bangumi_today/tools/log_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizes bearer headers, query parameters and JSON fields', () {
    var message = [
      'Authorization: Bearer bearer-secret',
      'https://example.test/callback?code=oauth-code&token=mikan-token',
      '{"access_token":"access-secret","refresh_token":"refresh-secret",'
          '"client_secret":"client-secret"}',
    ];

    var sanitized = BTLogTool.sanitize(message);

    expect(sanitized, contains('[REDACTED]'));
    for (var secret in [
      'bearer-secret',
      'oauth-code',
      'mikan-token',
      'access-secret',
      'refresh-secret',
      'client-secret',
    ]) {
      expect(sanitized, isNot(contains(secret)));
    }
  });
}
