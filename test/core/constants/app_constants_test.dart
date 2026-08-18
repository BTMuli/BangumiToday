// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/constants/app_constants.dart';

void main() {
  group('BTAppConstants Mikan URL', () {
    test('normalizes trailing slashes and empty values', () {
      expect(
        BTAppConstants.normalizeMikanUrl('https://mikanani.kas.pub/'),
        BTAppConstants.defaultMikanMirror,
      );
      expect(
        BTAppConstants.normalizeMikanUrl('   '),
        BTAppConstants.defaultMikanMirror,
      );
      expect(
        BTAppConstants.normalizeMikanUrl(null),
        BTAppConstants.defaultMikanMirror,
      );
      expect(
        BTAppConstants.normalizeMikanUrl(BTAppConstants.officialMikanMirror),
        BTAppConstants.officialMikanMirror,
      );
    });

    test('rewrites known Mikan hosts to the selected mirror', () {
      var target = BTAppConstants.defaultMikanMirror;
      var mappings = {
        'https://mikanani.me/Home/Bangumi/1':
            'https://mikanani.kas.pub/Home/Bangumi/1',
        'http://mikanime.tv/Download/a.torrent':
            'https://mikanani.kas.pub/Download/a.torrent',
        'https://www.mikanani.me/RSS/Classic':
            'https://mikanani.kas.pub/RSS/Classic',
        'https://mikanani.hacgn.fun/Home/Search?q=a':
            'https://mikanani.kas.pub/Home/Search?q=a',
      };

      for (var entry in mappings.entries) {
        expect(BTAppConstants.rewriteMikanUrl(entry.key, target), entry.value);
      }
    });

    test('rewrites kas.pub links back to the official site', () {
      expect(
        BTAppConstants.rewriteMikanUrl(
          'https://mikanani.kas.pub/Home/Bangumi/1',
          BTAppConstants.officialMikanMirror,
        ),
        'https://mikanani.me/Home/Bangumi/1',
      );
    });

    test('leaves non-Mikan URLs unchanged', () {
      expect(
        BTAppConstants.rewriteMikanUrl(
          'https://anibt.net/rss/magnets.xml',
          BTAppConstants.defaultMikanMirror,
        ),
        'https://anibt.net/rss/magnets.xml',
      );
    });
  });
}
