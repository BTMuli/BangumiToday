// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:hive/hive.dart';

// Project imports:
import '../database/bangumi/bangumi_user.dart';
import '../models/app/response.dart';
import '../models/bangumi/bangumi_model.dart';
import '../models/bangumi/bangumi_oauth_model.dart';
import '../models/hive/bgm_user_model.dart';
import '../request/bangumi/bangumi_oauth.dart';

/// Bangumi用户状态
class BgmUserHive extends ChangeNotifier {
  /// 单实例
  BgmUserHive._();

  static final BgmUserHive instance = BgmUserHive._();

  /// 获取实例
  factory BgmUserHive() => instance;

  /// 相关数据库
  final BtsBangumiUser sqlite = BtsBangumiUser();

  /// 相关api
  final BtrBangumiOauth api = BtrBangumiOauth();

  /// 获取box
  static Box<BgmUserHiveModel> get box => Hive.box<BgmUserHiveModel>('bgmUser');

  /// 获取模型
  BgmUserHiveModel get model => BgmUserHiveModel(
        user: _user,
        accessToken: _accessToken,
        refreshToken: _refreshToken,
        expireTime: _expireTime,
      );

  /// 用户
  BangumiUser? _user;

  /// accessToken
  String? _accessToken;

  /// refreshToken
  String? _refreshToken;

  /// expireTime
  DateTime? _expireTime;

  /// 获取用户
  BangumiUser? get user => _user;

  /// 获取accessToken
  String? get tokenAC => _accessToken;

  /// 获取refreshToken
  String? get tokenRF => _refreshToken;

  /// 获取expireTime
  DateTime? get expireTime => _expireTime;

  /// 初始化用户
  Future<void> initUser() async {
    var user = await sqlite.readUser();
    if (user != null) {
      _user = user;
    }
    var accessToken = await sqlite.readAccessToken();
    if (accessToken != null) {
      _accessToken = accessToken;
    }
    var refreshToken = await sqlite.readRefreshToken();
    if (refreshToken != null) {
      _refreshToken = refreshToken;
    }
    var expireTime = await sqlite.readExpireTime();
    if (expireTime != null) {
      _expireTime = expireTime;
    }
    await box.put('user', model);
    notifyListeners();
  }

  /// 更新数据
  Future<void> updateBox() async {
    await box.put('user', model);
  }

  /// 更新用户数据
  Future<void> updateUser(BangumiUser user, {bool update = true}) async {
    _user = user;
    await sqlite.writeUser(user);
    await box.put('user', model);
    if (update) await updateBox();
    notifyListeners();
  }

  /// 更新accessToken
  Future<void> updateAccessToken(String token, {bool update = true}) async {
    _accessToken = token;
    await sqlite.writeAccessToken(token);
    if (update) await updateBox();
    notifyListeners();
  }

  /// 更新refreshToken
  Future<void> updateRefreshToken(String token, {bool update = true}) async {
    _refreshToken = token;
    await sqlite.writeRefreshToken(token);
    if (update) await updateBox();
    notifyListeners();
  }

  /// 更新expireTime
  Future<void> updateExpireTime(int ts, {bool update = true}) async {
    await sqlite.writeExpireTime(ts);
    _expireTime = await sqlite.readExpireTime();
    if (update) await updateBox();
    notifyListeners();
  }

  /// 更新授权
  /// 返回 null 表示不需要刷新，返回 bool 表示是否刷新成功
  Future<bool?> refreshAuth({Future<void> Function(BTResponse)? onErr}) async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    if (_expireTime != null && DateTime.now().isBefore(_expireTime!)) {
      return null;
    }
    var resp = await api.refreshToken(_refreshToken!);
    if (resp.code != 0 || resp.data == null) {
      if (onErr != null) await onErr(resp);
      return false;
    }
    var data = resp.data! as BangumiOauthTokenRefreshData;
    await updateAccessToken(data.accessToken, update: false);
    await updateRefreshToken(data.refreshToken, update: false);
    await updateExpireTime(data.expiresIn, update: false);
    await updateBox();
    return true;
  }

  /// 检测是否过期，为null表示无法刷新
  Future<bool?> checkExpired() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return null;
    if (_expireTime != null && DateTime.now().isBefore(_expireTime!)) {
      return false;
    }
    return true;
  }
}
