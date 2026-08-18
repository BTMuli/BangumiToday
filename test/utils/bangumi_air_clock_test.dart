// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/utils/bangumi_utils.dart';

void main() {
  test('formats a local begin timestamp to HH:mm', () {
    expect(formatBangumiAirClock('2026-07-01T08:05:00'), '08:05');
  });

  test('returns null when begin is missing or invalid', () {
    expect(formatBangumiAirClock(null), isNull);
    expect(formatBangumiAirClock(''), isNull);
    expect(formatBangumiAirClock('not-a-date'), isNull);
  });
}
