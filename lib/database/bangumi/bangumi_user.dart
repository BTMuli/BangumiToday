import 'dart:convert';

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

  /// 初始化用户表
  /// 数据类型参考：lib/models/bangumi/user_request.dart
  Future<void> initUser() async {
    var check = await _instance.sqlite.isTableExist(_tableNameUser);
    if (!check) {
      await _instance.sqlite.db.execute('''
        CREATE TABLE $_tableNameUser (
          key TEXT NOT NULL PRIMARY KEY,
          value TEXT NOT NULL
        );
      ''');
      BTLogTool.info('Create table $_tableNameUser');
    } else {
      BTLogTool.warn('Table $_tableNameUser already exists');
      await _instance.sqlite.db.execute('DROP TABLE $_tableNameUser');
      BTLogTool.warn('Table $_tableNameUser dropped');
      await _instance.initUser();
    }
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
    BTLogTool.info('Read user info: $value');
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
      await _instance.sqlite.db.insert(
        _tableNameUser,
        {'key': 'user', 'value': jsonEncode(user)},
      );
      BTLogTool.info('Write user info: ${jsonEncode(user)}');
    } else {
      await _instance.sqlite.db.update(
        _tableNameUser,
        {'value': jsonEncode(user)},
        where: 'key = ?',
        whereArgs: ['user'],
      );
      BTLogTool.info('Update user info: ${jsonEncode(user)}');
    }
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

  /// 读取 refreshToken
  Future<String?> readRefreshToken() async {
    return readToken('refreshToken');
  }

  /// 写入/更新 refreshToken
  Future<void> writeRefreshToken(String token) async {
    await writeToken('refreshToken', token);
  }

  /// 读取token，通用
  Future<String?> readToken(String key) async {
    await _instance.preCheck();
    var result = await _instance.sqlite.db.query(
      _tableNameUser,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return null;
    var value = result.first['value'];
    BTLogTool.info('Read $key: $value');
    return value.toString();
  }

  /// 写入/更新token，通用
  Future<void> writeToken(String key, String value) async {
    await _instance.preCheck();
    var result = await _instance.sqlite.db.query(
      _tableNameUser,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) {
      await _instance.sqlite.db.insert(
        _tableNameUser,
        {'key': key, 'value': value},
      );
      BTLogTool.info('Write $key: $value');
    } else {
      await _instance.sqlite.db.update(
        _tableNameUser,
        {'value': value},
        where: 'key = ?',
        whereArgs: [key],
      );
      BTLogTool.info('Update $key: $value');
    }
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
    var expireTime;
    if (isTs) {
      var timeParse = DateTime.fromMillisecondsSinceEpoch(relativeTime);
      expireTime = timeParse.millisecondsSinceEpoch;
    } else {
      expireTime = DateTime.now().millisecondsSinceEpoch + relativeTime;
    }
    return writeToken('expireTime', expireTime.toString());
  }

  /// 判断是否过期
  Future<bool> isTokenExpired() async {
    var expireTime = await readToken('expireTime');
    if (expireTime == null) return true;
    var now = DateTime.now().millisecondsSinceEpoch;
    return now > int.parse(expireTime);
  }
}
