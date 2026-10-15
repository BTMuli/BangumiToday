// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

// Project imports:
import '../core/container.dart';
import '../database/bangumi/bangumi_collection.dart';
import '../database/bangumi/bangumi_user.dart';
import '../models/app/response.dart';
import '../models/bangumi/bangumi_model.dart';
import '../models/bangumi/bangumi_oauth_model.dart';
import '../models/hive/bgm_user_model.dart';
import '../request/bangumi/bangumi_oauth.dart';

final bgmUserStoreProvider = NotifierProvider<BgmUserStore, BgmUserState>(
  BgmUserStore.new,
);

/// 登录用户与授权凭据的内存快照。
///
/// 凭据只保存在内存与系统安全存储中；[BgmUserHiveModel] 的旧 token 槽位仅
/// 用于读取历史记录，不写回。
@immutable
class BgmUserState {
  /// 构造函数
  const BgmUserState({
    this.user,
    this.accessToken,
    this.refreshToken,
    this.expireTime,
    this.sessionGeneration = 0,
  });

  /// 当前登录用户
  final BangumiUser? user;

  /// accessToken
  final String? accessToken;

  /// refreshToken
  final String? refreshToken;

  /// expireTime
  final DateTime? expireTime;

  /// Changes on logout or a new login; token renewal keeps the same session.
  final int sessionGeneration;

  /// 是否已登录
  bool get loggedIn => user != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BgmUserState) return false;
    return identical(user, other.user) &&
        accessToken == other.accessToken &&
        refreshToken == other.refreshToken &&
        expireTime == other.expireTime &&
        sessionGeneration == other.sessionGeneration;
  }

  @override
  int get hashCode => Object.hash(
    identityHashCode(user),
    accessToken,
    refreshToken,
    expireTime,
    sessionGeneration,
  );
}

/// Bangumi 用户与授权凭据状态。
///
/// 表、Hive box 与 OAuth 客户端留在实现内部，对外只发布不可变快照。写入顺序
/// 统一为“先持久化、再替换内存状态”，避免请求在刷新过程中读到半套凭据。
class BgmUserStore extends Notifier<BgmUserState> {
  Future<void> _accountWrites = Future.value();

  /// 安全存储没有跨 key 事务，账号的写入与清理共用一条队列。
  Future<T> _writeAccount<T>(Future<T> Function() action) {
    var next = _accountWrites.then((_) => action());
    _accountWrites = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  Future<void> settleWrites() => _accountWrites;

  /// 相关数据库
  final BtsBangumiUser sqlite = BtsBangumiUser();

  /// 相关api
  final BtrBangumiOauth api = BtrBangumiOauth();

  /// 获取box
  static Box<BgmUserHiveModel> get box => Hive.box<BgmUserHiveModel>('bgmUser');

  /// 当前状态
  BgmUserState get data => state;

  /// 获取用户
  BangumiUser? get user => state.user;

  /// 获取accessToken
  String? get tokenAC => state.accessToken;

  /// 获取refreshToken
  String? get tokenRF => state.refreshToken;

  /// 获取expireTime
  DateTime? get expireTime => state.expireTime;

  @override
  BgmUserState build() {
    ref.onDispose(api.client.dispose);
    return const BgmUserState();
  }

  BgmUserHiveModel _model() =>
      BgmUserHiveModel(user: state.user, expireTime: state.expireTime);

  /// 初始化用户
  Future<void> initUser() async {
    // Older releases persisted tokens in the Hive record as well as SQLite.
    // Feed those legacy slots through BtsBangumiUser once before replacing
    // the record, so upgrading cannot silently log the user out.
    var legacyModel = box.get('user');
    var user = await sqlite.readUser();
    var legacyAccessToken = legacyModel?.accessToken;
    // A restored Hive snapshot can belong to a different account from SQLite
    // or secure storage. Never combine credentials from those two identities.
    var legacyMatchesUser = user == null || user.id == legacyModel?.user?.id;
    var accessToken = await sqlite.readAccessToken();
    if (accessToken == null &&
        legacyMatchesUser &&
        legacyAccessToken != null &&
        legacyAccessToken.isNotEmpty) {
      await sqlite.writeAccessToken(legacyAccessToken);
      accessToken = await sqlite.readAccessToken();
    }
    var usingLegacyAccount =
        legacyMatchesUser &&
        legacyAccessToken != null &&
        legacyAccessToken.isNotEmpty &&
        accessToken == legacyAccessToken;
    var refreshToken = await sqlite.readRefreshToken();
    if (refreshToken == null &&
        usingLegacyAccount &&
        legacyModel?.refreshToken != null) {
      await sqlite.writeRefreshToken(legacyModel!.refreshToken!);
      refreshToken = await sqlite.readRefreshToken();
    }
    var expireTime = await sqlite.readExpireTime();
    if (usingLegacyAccount) {
      // Restore the complete legacy snapshot before clearing its old slots.
      // Its expiry already includes the old five-minute safety margin.
      if (user == null && legacyModel?.user != null) {
        user = legacyModel!.user!;
        await sqlite.writeUser(user);
      }
      if (expireTime == null && legacyModel?.expireTime != null) {
        expireTime = legacyModel!.expireTime!;
        await sqlite.writeToken(
          'expireTime',
          expireTime.millisecondsSinceEpoch.toString(),
        );
      }
    }
    var recovered = BgmUserState(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expireTime: expireTime,
    );
    await box.put('user', BgmUserHiveModel(user: user, expireTime: expireTime));
    await BtsBangumiCollection().setOwner(
      user?.id.toString(),
      adoptLegacy: true,
    );
    state = recovered;
  }

  /// 删除用户
  Future<void> deleteUser() async {
    state = BgmUserState(sessionGeneration: state.sessionGeneration + 1);
    await _writeAccount(() async {
      await BtsBangumiCollection().setOwner(null);
      await sqlite.deleteUser();
      await sqlite.deleteAccessToken();
      await sqlite.deleteRefreshToken();
      await sqlite.deleteExpireTime();
      await box.put('user', _model());
    });
  }

  /// 更新用户数据
  Future<void> updateUser(BangumiUser user) async {
    if (state.user?.id != user.id) {
      state = BgmUserState(
        accessToken: state.accessToken,
        refreshToken: state.refreshToken,
        expireTime: state.expireTime,
        sessionGeneration: state.sessionGeneration + 1,
      );
    }
    var generation = state.sessionGeneration;
    await _writeAccount(() async {
      if (!ref.mounted || state.sessionGeneration != generation) return;
      var collections = BtsBangumiCollection();
      var saved = await collections.writeScoped(() async {
        await collections.setOwner(user.id.toString());
        await sqlite.writeUser(user);
      }, isCurrent: () => ref.mounted && state.sessionGeneration == generation);
      if (!saved) return;
      state = BgmUserState(
        user: user,
        accessToken: state.accessToken,
        refreshToken: state.refreshToken,
        expireTime: state.expireTime,
        sessionGeneration: generation,
      );
      await box.put('user', _model());
    });
  }

  /// 一次性更新一组授权信息。
  ///
  /// 安全存储的多个 key 没有跨 key 事务，因此先完成所有持久化写入，再替换
  /// 内存状态，避免请求在刷新过程中读到半套凭据。
  Future<bool> updateTokenSet({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
    bool newSession = false,
    int? expectedGeneration,
    String? expectedRefreshToken,
  }) async {
    if (newSession) {
      // Hide the previous account immediately, but keep its owned cache until
      // user info establishes the new identity. Reauthorizing the same account
      // must not discard all collections; a different owner clears them there.
      state = BgmUserState(sessionGeneration: state.sessionGeneration + 1);
    }
    var generation = expectedGeneration ?? state.sessionGeneration;
    return _writeAccount(() async {
      if (!ref.mounted ||
          state.sessionGeneration != generation ||
          (expectedRefreshToken != null &&
              state.refreshToken != expectedRefreshToken)) {
        return false;
      }
      if (newSession) {
        await sqlite.deleteUser();
        await box.put('user', _model());
      }
      await sqlite.writeAccessToken(accessToken);
      await sqlite.writeRefreshToken(refreshToken);
      await sqlite.writeExpireTime(expiresIn);
      var expireTime = await sqlite.readExpireTime();
      // 退出和重新登录会立即使旧会话失效，后续排队的清理/写入负责落盘。
      if (!ref.mounted || state.sessionGeneration != generation) return false;
      state = BgmUserState(
        user: state.user,
        accessToken: accessToken,
        refreshToken: refreshToken,
        expireTime: expireTime,
        sessionGeneration: generation,
      );
      await box.put('user', _model());
      return true;
    });
  }

  /// 更新授权
  /// 返回 null 表示不需要刷新，返回 bool 表示是否刷新成功
  Future<bool?> refreshAuth({
    Future<void> Function(BTResponse)? onErr,
    bool force = false,
  }) async {
    var generation = state.sessionGeneration;
    var refreshToken = state.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;
    if (!force) {
      var shouldRefresh = await checkExpired();
      if (shouldRefresh != true) return null;
    }
    var resp = await api.refreshToken(refreshToken);
    if (resp.code != 0 || resp.data == null) {
      if (onErr != null) await onErr(resp);
      return false;
    }
    var data = resp.data! as BangumiOauthTokenRefreshData;
    return updateTokenSet(
      accessToken: data.accessToken,
      refreshToken: data.refreshToken,
      expiresIn: data.expiresIn,
      expectedGeneration: generation,
      expectedRefreshToken: refreshToken,
    );
  }

  /// 检测是否过期，为null表示无法刷新
  Future<bool?> checkExpired() async {
    var refreshToken = state.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return null;
    var expireTime = state.expireTime;
    if (expireTime != null) {
      var refreshAt = expireTime.subtract(const Duration(days: 1));
      return !DateTime.now().isBefore(refreshAt);
    }
    return true;
  }
}

/// Widget 树之外的调用方（数据库初始化、Token 刷新服务）通过该访问器读写同一个
/// notifier，不复制第二份用户状态。
class BgmUserHive {
  BgmUserHive._();

  static BgmUserStore get _store =>
      globalContainer.read(bgmUserStoreProvider.notifier);

  /// 当前登录用户
  static BangumiUser? get user => _store.user;

  /// accessToken
  static String? get tokenAC => _store.tokenAC;

  /// refreshToken
  static String? get tokenRF => _store.tokenRF;

  /// expireTime
  static DateTime? get expireTime => _store.expireTime;

  static int get sessionGeneration => _store.data.sessionGeneration;

  /// 初始化用户
  static Future<void> initUser() => _store.initUser();

  /// 更新token集合
  static Future<bool> updateTokenSet({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
    required int expectedGeneration,
    required String expectedRefreshToken,
  }) => _store.updateTokenSet(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresIn: expiresIn,
    expectedGeneration: expectedGeneration,
    expectedRefreshToken: expectedRefreshToken,
  );
}
