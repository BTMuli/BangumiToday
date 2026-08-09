// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Project imports:
import '../../tools/log_tool.dart';
import 'app_config.dart';

/// MikanProject 订阅 Token 安全存储。
///
/// Token 只写入系统安全存储；旧版 `AppConfig` 表中的明文副本会在首次读取时
/// 迁移到安全存储并删除，迁移失败时保留旧存储作为兼容回退路径。
class BtsMikanCredential {
  BtsMikanCredential({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// 安全存储实例，测试时可注入失败实现。
  final FlutterSecureStorage _secureStorage;

  /// 安全存储 key。
  static const String _secureKey = 'mikan.token';

  /// 旧版 AppConfig 明文键名，仅用于迁移与回退。
  static const String legacyConfigKey = 'mikanToken';

  final BtsAppConfig _configDb = BtsAppConfig();

  /// 读取 Mikan Token，优先安全存储；必要时迁移旧明文副本。
  Future<String?> readToken() async {
    try {
      var secureValue = await _secureStorage.read(key: _secureKey);
      if (secureValue != null && secureValue.isNotEmpty) {
        return secureValue;
      }
    } catch (error) {
      BTLogTool.warn('读取系统安全存储失败，将尝试迁移旧凭据：$error');
    }

    var legacyValue = await _configDb.read(legacyConfigKey);
    if (legacyValue == null || legacyValue.isEmpty) return null;

    try {
      await _secureStorage.write(key: _secureKey, value: legacyValue);
      await _configDb.delete(legacyConfigKey);
      BTLogTool.info('Mikan 凭据已迁移到系统安全存储');
    } catch (error) {
      BTLogTool.warn('迁移旧 Mikan 凭据失败，保留旧存储兼容路径：$error');
    }
    return legacyValue;
  }

  /// 写入 Mikan Token 到安全存储；插件失败时回退旧存储路径。
  Future<void> writeToken(String token) async {
    try {
      await _secureStorage.write(key: _secureKey, value: token);
      await _configDb.delete(legacyConfigKey);
      BTLogTool.info('Write Mikan credential');
      return;
    } catch (error) {
      BTLogTool.warn('写入系统安全存储失败，将保留旧存储兼容路径：$error');
    }
    await _configDb.write(legacyConfigKey, token);
  }

  /// 删除 Mikan Token，同时清理安全存储与旧明文副本。
  Future<void> deleteToken() async {
    try {
      await _secureStorage.delete(key: _secureKey);
    } catch (error) {
      BTLogTool.warn('删除系统安全存储凭据失败：$error');
    }
    await _configDb.delete(legacyConfigKey);
  }
}
