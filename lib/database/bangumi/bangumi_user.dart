// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Project imports:
import '../../models/bangumi/bangumi_model.dart';
import '../../tools/log_tool.dart';
import '../bt_sqlite.dart';

/// bangumi.tv 用户相关数据
/// 目前只有用户信息跟 token 信息
/// 详细文档请参考 https://bangumi.github.io/api
class BtsBangumiUser {
  BtsBangumiUser._();

  /// 实例
  static final BtsBangumiUser _instance = BtsBangumiUser._();

  /// 获取实例
  factory BtsBangumiUser() => _instance;

  /// 数据库
  final BTSqlite sqlite = BTSqlite();

  /// 表名-用户
  final String _tableNameUser = 'BangumiUser';

  /// 系统安全存储。旧版 SQLite 凭据会在首次读取时迁移到这里。
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const Set<String> _secureTokenKeys = {'accessToken', 'refreshToken'};

  static String _secureKey(String key) => 'bangumi.$key';

  /// 初始化用户表
  /// 数据类型参考：lib/models/bangumi/user_request.dart
  Future<void> initUser() async {
    await _instance.sqlite.db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableNameUser (
          key TEXT NOT NULL PRIMARY KEY,
          value TEXT NOT NULL
        );
      ''');
    BTLogTool.info('Ensure table $_tableNameUser exists');
  }

  /// 前置检查
  Future<void> preCheck() async {
    var check = await _instance.sqlite.isTableExist(_tableNameUser);
    if (!check) {
      await _instance.initUser();
    }
  }

  /// 读取用户信息
  Future<BangumiUser?> readUser() async {
    await _instance.preCheck();
    var result = await _instance.sqlite.db.query(
      _tableNameUser,
      where: 'key = ?',
      whereArgs: ['user'],
    );
    if (result.isEmpty) return null;
    var value = result.first['value'];
    if (value == null || value == '') return null;
    return BangumiUser.fromJson(jsonDecode(value as String));
  }

  /// 写入/更新用户信息
  Future<void> writeUser(BangumiUser user) async {
    await _instance.preCheck();
    var result = await _instance.sqlite.db.query(
      _tableNameUser,
      where: 'key = ?',
      whereArgs: ['user'],
    );
    if (result.isEmpty) {
      await _instance.sqlite.db.insert(_tableNameUser, {
        'key': 'user',
        'value': jsonEncode(user),
      });
    } else {
      await _instance.sqlite.db.update(
        _tableNameUser,
        {'value': jsonEncode(user)},
        where: 'key = ?',
        whereArgs: ['user'],
      );
    }
  }

  /// 删除用户信息
  Future<void> deleteUser() async {
    await _instance.preCheck();
    await _instance.sqlite.db.delete(
      _tableNameUser,
      where: 'key = ?',
      whereArgs: ['user'],
    );
  }

  /// 判断有没有登录
  Future<bool> isLogin() async {
    var accessToken = await readAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  /// 读取 accessToken
  Future<String?> readAccessToken() async {
    return readToken('accessToken');
  }

  /// 写入/更新 accessToken
  Future<void> writeAccessToken(String token) async {
    await writeToken('accessToken', token);
  }

  /// 删除 accessToken
  Future<void> deleteAccessToken() async {
    await deleteToken('accessToken');
  }

  /// 读取 refreshToken
  Future<String?> readRefreshToken() async {
    return readToken('refreshToken');
  }

  /// 写入/更新 refreshToken
  Future<void> writeRefreshToken(String token) async {
    await writeToken('refreshToken', token);
  }

  /// 删除 refreshToken
  Future<void> deleteRefreshToken() async {
    await deleteToken('refreshToken');
  }

  /// 读取token，通用
  Future<String?> readToken(String key) async {
    if (_secureTokenKeys.contains(key)) {
      try {
        var secureValue = await _secureStorage.read(key: _secureKey(key));
        if (secureValue != null && secureValue.isNotEmpty) {
          return secureValue;
        }
      } catch (error) {
        BTLogTool.warn('读取系统安全存储失败，将尝试迁移旧凭据：$error');
      }
    }

    await _instance.preCheck();
    var result = await _instance.sqlite.db.query(
      _tableNameUser,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return null;
    var value = result.first['value'];
    var legacyValue = value?.toString();
    if (legacyValue == null || legacyValue.isEmpty) return legacyValue;

    if (_secureTokenKeys.contains(key)) {
      try {
        await _secureStorage.write(key: _secureKey(key), value: legacyValue);
        await _instance.sqlite.db.delete(
          _tableNameUser,
          where: 'key = ?',
          whereArgs: [key],
        );
      } catch (error) {
        BTLogTool.warn('迁移旧用户凭据失败：$error');
      }
    }
    return legacyValue;
  }

  /// 写入/更新token，通用
  Future<void> writeToken(String key, String value) async {
    if (_secureTokenKeys.contains(key)) {
      try {
        await _secureStorage.write(key: _secureKey(key), value: value);
        await _instance.preCheck();
        await _instance.sqlite.db.delete(
          _tableNameUser,
          where: 'key = ?',
          whereArgs: [key],
        );
        BTLogTool.info('Write user credential: $key');
        return;
      } catch (error) {
        BTLogTool.warn('写入系统安全存储失败，将保留旧存储兼容路径：$error');
      }
    }

    await _instance.preCheck();
    var result = await _instance.sqlite.db.query(
      _tableNameUser,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) {
      await _instance.sqlite.db.insert(_tableNameUser, {
        'key': key,
        'value': value,
      });
      BTLogTool.info('Write user credential: $key');
    } else {
      await _instance.sqlite.db.update(
        _tableNameUser,
        {'value': value},
        where: 'key = ?',
        whereArgs: [key],
      );
    }
  }

  /// 删除token，通用
  Future<void> deleteToken(String key) async {
    if (_secureTokenKeys.contains(key)) {
      try {
        await _secureStorage.delete(key: _secureKey(key));
      } catch (error) {
        BTLogTool.warn('删除系统安全存储凭据失败：$error');
      }
    }
    await _instance.preCheck();
    await _instance.sqlite.db.delete(
      _tableNameUser,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  /// 读取过期时间
  Future<DateTime?> readExpireTime() async {
    var expireTime = await readToken('expireTime');
    if (expireTime == null) return null;
    try {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(expireTime));
    } on Exception catch (e) {
      BTLogTool.error('Failed to parse expireTime: $e');
      return null;
    }
  }

  /// 写入/更新过期时间
  Future<void> writeExpireTime(int expiresIn, {bool isTs = false}) {
    var relativeTime = expiresIn * 1000 - 300000;
    int expireTime;
    if (isTs) {
      var timeParse = DateTime.fromMillisecondsSinceEpoch(relativeTime);
      expireTime = timeParse.millisecondsSinceEpoch;
    } else {
      expireTime = DateTime.now().millisecondsSinceEpoch + relativeTime;
    }
    return writeToken('expireTime', expireTime.toString());
  }

  /// 删除过期时间
  Future<void> deleteExpireTime() async {
    await deleteToken('expireTime');
  }

  /// 判断是否过期
  Future<bool> isTokenExpired() async {
    var expireTime = await readToken('expireTime');
    if (expireTime == null) return true;
    var now = DateTime.now().millisecondsSinceEpoch;
    return now > int.parse(expireTime);
  }
}
