// Project imports:
import '../../database/app/app_config.dart';
import '../../domain/repositories/playback_settings.dart';

/// 现有 AppConfig 表实现。
class AppPlaybackSettingsStore implements PlaybackSettingsStore {
  AppPlaybackSettingsStore({BtsAppConfig? config})
    : _config = config ?? BtsAppConfig();

  final BtsAppConfig _config;

  @override
  Future<String?> read(String key) => _config.read(key);

  @override
  Future<void> write(String key, String value) => _config.write(key, value);
}
