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
  BgmUserHiveModel get model =>
      BgmUserHiveModel(user: _user, expireTime: _expireTime);

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
    // Older releases persisted tokens in the Hive record as well as SQLite.
    // Feed those legacy slots through BtsBangumiUser once before replacing
    // the record, so upgrading cannot silently log the user out.
    var legacyModel = box.get('user');
    var user = await sqlite.readUser();
    if (user != null) {
      _user = user;
    }
    var accessToken = await sqlite.readAccessToken();
    if (accessToken == null && legacyModel?.accessToken != null) {
      await sqlite.writeAccessToken(legacyModel!.accessToken!);
      accessToken = await sqlite.readAccessToken();
    }
    if (accessToken != null) {
      _accessToken = accessToken;
    }
    var refreshToken = await sqlite.readRefreshToken();
    if (refreshToken == null && legacyModel?.refreshToken != null) {
      await sqlite.writeRefreshToken(legacyModel!.refreshToken!);
      refreshToken = await sqlite.readRefreshToken();
    }
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

  /// 删除用户
  Future<void> deleteUser() async {
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _expireTime = null;
    await sqlite.deleteUser();
    await sqlite.deleteAccessToken();
    await sqlite.deleteRefreshToken();
    await sqlite.deleteExpireTime();
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

  /// 一次性更新一组授权信息。
  ///
  /// 安全存储的多个 key 没有跨 key 事务，因此先完成所有持久化写入，再替换
  /// 内存状态并通知监听者，避免请求在刷新过程中读到半套凭据。
  Future<void> updateTokenSet({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    await sqlite.writeAccessToken(accessToken);
    await sqlite.writeRefreshToken(refreshToken);
    await sqlite.writeExpireTime(expiresIn);

    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _expireTime = await sqlite.readExpireTime();
    await updateBox();
    notifyListeners();
  }

  /// 更新授权
  /// 返回 null 表示不需要刷新，返回 bool 表示是否刷新成功
  Future<bool?> refreshAuth({
    Future<void> Function(BTResponse)? onErr,
    bool force = false,
  }) async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    if (!force) {
      var shouldRefresh = await checkExpired();
      if (shouldRefresh != true) return null;
    }
    var resp = await api.refreshToken(_refreshToken!);
    if (resp.code != 0 || resp.data == null) {
      if (onErr != null) await onErr(resp);
      return false;
    }
    var data = resp.data! as BangumiOauthTokenRefreshData;
    await updateTokenSet(
      accessToken: data.accessToken,
      refreshToken: data.refreshToken,
      expiresIn: data.expiresIn,
    );
    return true;
  }

  /// 检测是否过期，为null表示无法刷新
  Future<bool?> checkExpired() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return null;
    if (_expireTime != null) {
      var refreshAt = _expireTime!.subtract(const Duration(days: 1));
      return !DateTime.now().isBefore(refreshAt);
    }
    return true;
  }
}
