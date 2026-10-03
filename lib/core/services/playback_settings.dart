// Project imports:
import '../../database/app/app_config.dart';

/// 播放器的本地配置读写接口（倍速记忆、画面适配等）。
abstract class PlaybackSettingsStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

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
