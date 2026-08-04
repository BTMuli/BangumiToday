import 'package:bangumi_today/core/utils/window_effect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isMicaSupported', () {
    test('supports Windows 11 with localized Build text', () {
      expect(
        isMicaSupported(
          operatingSystemVersion: 'Windows 11 家庭版" 10.0 (Build 26200)',
        ),
        isTrue,
      );
    });

    test('supports Windows 11 with dotted version format', () {
      expect(
        isMicaSupported(operatingSystemVersion: 'Windows 10.0.22631'),
        isTrue,
      );
    });

    test('supports the first Windows 11 build', () {
      expect(
        isMicaSupported(
          operatingSystemVersion: 'Windows 11 家庭版" 10.0 (Build 22000)',
        ),
        isTrue,
      );
    });

    test('rejects Windows 10 builds', () {
      expect(
        isMicaSupported(operatingSystemVersion: 'Windows 10.0.19045'),
        isFalse,
      );
    });

    test('rejects pre-release builds below 22000', () {
      expect(
        isMicaSupported(
          operatingSystemVersion: 'Windows 11 家庭版" 10.0 (Build 21996)',
        ),
        isFalse,
      );
    });

    test('rejects non-Windows version strings', () {
      expect(
        isMicaSupported(operatingSystemVersion: 'macOS 13.0'),
        isFalse,
      );
    });
  });
}
