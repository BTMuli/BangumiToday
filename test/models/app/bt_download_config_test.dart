import 'package:bangumi_today/models/app/bt_download_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the engine defaults and serializes every protocol field', () {
    const config = BtDownloadConfig();

    expect(config.toJson(), {
      'activeDownloads': 2,
      'downloadRateLimit': 0,
      'uploadRateLimit': 1024 * 1024,
      'connectionsLimit': 200,
      'connectionsPerTask': 80,
      'metadataTimeoutSeconds': 300,
      'seedingEnabled': false,
      'seedRatioLimit': 2.0,
      'seedTimeLimitMinutes': 60,
      'seedingDisclosureAccepted': false,
    });
    expect(config.downloadRateLimitKiB, 0);
    expect(config.uploadRateLimitKiB, 1024);
  });

  test('round trips customized settings', () {
    var original = const BtDownloadConfig().copyWith(
      activeDownloads: 4,
      downloadRateLimit: 2048 * 1024,
      uploadRateLimit: 512 * 1024,
      connectionsLimit: 500,
      connectionsPerTask: 100,
      metadataTimeoutSeconds: 600,
      seedingEnabled: true,
      seedRatioLimit: 1.5,
      seedTimeLimitMinutes: 90,
      seedingDisclosureAccepted: true,
    );

    var restored = BtDownloadConfig.fromJson(original.toJson());

    expect(restored.toJson(), original.toJson());
  });

  test('rejects settings outside the engine contract', () {
    expect(
      () => BtDownloadConfig.fromJson({
        'activeDownloads': 0,
        'connectionsLimit': 200,
        'connectionsPerTask': 80,
        'metadataTimeoutSeconds': 300,
      }),
      throwsFormatException,
    );
    expect(
      () => const BtDownloadConfig(
        connectionsLimit: 20,
        connectionsPerTask: 21,
      ).validate(),
      throwsFormatException,
    );
  });

  test('keeps upgrades safe and gates fresh-install seeding on disclosure', () {
    var upgraded = BtDownloadConfig.fromJson({
      'activeDownloads': 2,
      'connectionsLimit': 200,
      'connectionsPerTask': 80,
      'metadataTimeoutSeconds': 300,
    });
    const fresh = BtDownloadConfig.freshInstall();

    expect(upgraded.seedingEnabled, isFalse);
    expect(fresh.seedingEnabled, isTrue);
    expect(fresh.toEngineJson()['seedingEnabled'], isFalse);
    expect(
      fresh
          .copyWith(seedingDisclosureAccepted: true)
          .toEngineJson(
            additionalTrackers: ['udp://tracker.test:80/'],
          )['seedingEnabled'],
      isTrue,
    );
  });

  test('rejects unbounded enabled seeding', () {
    expect(
      () => const BtDownloadConfig(
        seedingEnabled: true,
        seedRatioLimit: 0,
        seedTimeLimitMinutes: 0,
      ).validate(),
      throwsFormatException,
    );
  });
}
