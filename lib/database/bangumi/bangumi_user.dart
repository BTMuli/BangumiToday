// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Project imports:
import '../../models/bangumi/bangumi_model.dart';
import '../../tools/log_tool.dart';
import '../bt_sqlite.dart';
import '../drift/bt_database.dart';

/// bangumi.tv 用户相关数据
/// 目前只有用户信息跟 token 信息
/// 详细文档请参考 https://bangumi.github.io/api
///
/// 建表与补列由 `BtDatabase` 拥有，这里只做表存取。
class BtsBangumiUser {
  BtsBangumiUser._();

  /// 实例
  static final BtsBangumiUser _instance = BtsBangumiUser._();

  /// 获取实例
  factory BtsBangumiUser() => _instance;

  /// 数据库
  BtDatabase get _db => BTSqlite().db;

  /// 系统安全存储。旧版 SQLite 凭据会在首次读取时迁移到这里。
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const Set<String> _secureTokenKeys = {'accessToken', 'refreshToken'};

  static String _secureKey(String key) => 'bangumi.$key';

  /// 读取用户信息
  Future<BangumiUser?> readUser() async {
    var row = await _readRow('user');
    if (row == null) return null;
    if (row.value.isEmpty) return null;
    return BangumiUser.fromJson(jsonDecode(row.value));
  }

  /// 写入/更新用户信息
  Future<void> writeUser(BangumiUser user) async {
    await _writeRow('user', jsonEncode(user));
  }

  /// 删除用户信息
  Future<void> deleteUser() async {
    await _deleteRow('user');
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

    var row = await _readRow(key);
    if (row == null) return null;
    var legacyValue = row.value;
    if (legacyValue.isEmpty) return legacyValue;

    if (_secureTokenKeys.contains(key)) {
      try {
        await _secureStorage.write(key: _secureKey(key), value: legacyValue);
        await _deleteRow(key);
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
        await _deleteRow(key);
        BTLogTool.info('Write user credential: $key');
        return;
      } catch (error) {
        BTLogTool.warn('写入系统安全存储失败，将保留旧存储兼容路径：$error');
      }
    }

    var existing = await _readRow(key);
    await _writeRow(key, value);
    if (existing == null) {
      BTLogTool.info('Write user credential: $key');
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
    await _deleteRow(key);
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

  Future<UserRow?> _readRow(String key) {
    var query = _db.select(_db.bangumiUser)
      ..where((table) => table.key.equals(key));
    return query.getSingleOrNull();
  }

  Future<void> _writeRow(String key, String value) {
    return _db
        .into(_db.bangumiUser)
        .insertOnConflictUpdate(
          BangumiUserCompanion.insert(key: key, value: value),
        );
  }

  Future<void> _deleteRow(String key) {
    var delete = _db.delete(_db.bangumiUser)
      ..where((table) => table.key.equals(key));
    return delete.go();
  }
}
