// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/models/app/bt_tracker_config.dart';
import 'package:bangumi_today/store/tracker_hive.dart';

void main() {
  test('normalizes and validates Tracker URLs', () {
    expect(
      normalizeTrackerUrl('HTTP://Tracker.Example:80/announce?pass=AbC'),
      'http://tracker.example/announce?pass=AbC',
    );
    expect(
      normalizeTrackerUrl('udp://[2001:DB8::1]:6969/announce'),
      'udp://[2001:db8::1]:6969/announce',
    );
    expect(
      () => normalizeTrackerUrl('udp://tracker.example/announce'),
      throwsFormatException,
    );
    expect(
      () => normalizeTrackerUrl('https://user:secret@tracker.example/announce'),
      throwsFormatException,
    );
  });

  test('parses lists without letting malformed entries poison the source', () {
    var trackers = parseTrackerText('''
      # comment
      udp://tracker.example:6969/announce
      invalid
      HTTPS://TRACKER.EXAMPLE:443/announce
      udp://tracker.example:6969/announce
    ''');

    expect(trackers, [
      'udp://tracker.example:6969/announce',
      'https://tracker.example/announce',
    ]);
  });

  test('merges manual Trackers first and caps the effective list', () {
    var remote = List.generate(
      520,
      (index) => 'udp://tracker$index.example:6969/announce',
    );
    var merged = mergeTrackers(['https://manual.example/announce'], [remote]);

    expect(merged, hasLength(512));
    expect(merged.first, 'https://manual.example/announce');
  });

  test('round trips Tracker source settings and timestamps', () {
    var original = BtTrackerConfig(
      sources: const ['https://lists.example/trackers.txt'],
      manualTrackers: const ['udp://tracker.example:6969/announce'],
      autoUpdate: false,
      lastUpdateAttemptAt: DateTime.utc(2026, 8, 2, 10),
      lastUpdateSuccessAt: DateTime.utc(2026, 8, 2, 10, 1),
      lastUpdateError: 'partial failure',
      sourceEtags: const {'https://lists.example/trackers.txt': '"v1"'},
      sourceLastModified: const {
        'https://lists.example/trackers.txt': 'Sun, 02 Aug 2026 10:00:00 GMT',
      },
    );

    var restored = BtTrackerConfig.fromJson(original.toJson());

    expect(restored.sources, original.sources);
    expect(restored.manualTrackers, original.manualTrackers);
    expect(restored.autoUpdate, isFalse);
    expect(restored.lastUpdateError, 'partial failure');
    expect(restored.sourceEtags, original.sourceEtags);
    expect(restored.sourceLastModified, original.sourceLastModified);
    expect(restored.lastUpdateSuccessAt?.toUtc(), original.lastUpdateSuccessAt);
  });
}
