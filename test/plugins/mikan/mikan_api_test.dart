// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/constants/app_constants.dart';
import 'package:bangumi_today/plugins/mikan/mikan_api.dart';

void main() {
  group('BtrMikanApi base URL', () {
    setUp(() {
      BtrMikanApi.setBaseUrl(BTAppConstants.defaultMikanMirror);
    });

    tearDown(() {
      BtrMikanApi.setBaseUrl(BTAppConstants.defaultMikanMirror);
    });

    test('defaults to the kas.pub mirror', () {
      expect(BtrMikanApi.baseUrl, BTAppConstants.defaultMikanMirror);
    });

    test('removes trailing slashes', () {
      BtrMikanApi.setBaseUrl('https://mikanani.kas.pub///');

      expect(BtrMikanApi.baseUrl, BTAppConstants.defaultMikanMirror);
    });

    test('falls back to kas.pub for an empty URL', () {
      BtrMikanApi.setBaseUrl('   ');

      expect(BtrMikanApi.baseUrl, BTAppConstants.defaultMikanMirror);
    });
  });

  group('BtrMikanApi domain rewriting', () {
    tearDown(() {
      BtrMikanApi.setBaseUrl(BTAppConstants.defaultMikanMirror);
    });

    test('rewrites site links for the kas.pub mirror', () {
      BtrMikanApi.setBaseUrl(BTAppConstants.defaultMikanMirror);

      expect(
        BtrMikanApi.rewriteUrl('https://mikanani.me/Home/Bangumi/1'),
        'https://mikanani.kas.pub/Home/Bangumi/1',
      );
    });
  });
}
