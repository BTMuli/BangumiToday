/// 播放器的本地配置读写接口（倍速记忆、画面适配等）。
abstract class PlaybackSettingsStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}
