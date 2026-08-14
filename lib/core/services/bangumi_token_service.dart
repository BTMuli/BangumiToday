// Project imports:
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_oauth_model.dart';
import '../../request/bangumi/bangumi_oauth.dart';
import '../../store/bgm_user_hive.dart';
import '../../tools/log_tool.dart';

/// 刷新授权所需的 Token 状态读取器。
typedef BangumiTokenReader = String? Function();

/// 刷新授权所需的过期时间读取器。
typedef BangumiExpireTimeReader = DateTime? Function();

/// 刷新成功后的 Token 状态写入器。
typedef BangumiTokenSetWriter =
    Future<void> Function({
      required String accessToken,
      required String refreshToken,
      required int expiresIn,
    });

/// OAuth refresh token 请求器。
typedef BangumiTokenRefresher =
    Future<BTResponse> Function(String refreshToken);

/// Token 刷新结果。
enum BangumiTokenRefreshResult {
  /// 当前 Token 尚未进入刷新窗口。
  notNeeded,

  /// 已成功刷新并切换到新 Token。
  refreshed,

  /// 缺少 refresh token，无法刷新。
  unavailable,

  /// 刷新请求失败或返回了无效数据。
  failed,
}

/// Bangumi Token 的统一刷新协调器。
///
/// 请求前刷新、401 强制刷新和启动预刷新都必须经过同一个实例，避免多个
/// Dio 客户端同时使用同一个 refresh token 发起刷新请求。
class BangumiTokenService {
  /// 提前刷新窗口。持久化的过期时间已经包含旧版本的 5 分钟安全余量。
  static const Duration defaultRefreshAhead = Duration(days: 1);

  /// 应用级单例。
  static final BangumiTokenService instance = BangumiTokenService._default();

  BangumiTokenService._({
    required BangumiTokenReader readAccessToken,
    required BangumiTokenReader readRefreshToken,
    required BangumiExpireTimeReader readExpireTime,
    required BangumiTokenRefresher refreshToken,
    required BangumiTokenSetWriter writeTokenSet,
    required DateTime Function() now,
    this.refreshAhead = BangumiTokenService.defaultRefreshAhead,
  }) : _readAccessToken = readAccessToken,
       _readRefreshToken = readRefreshToken,
       _readExpireTime = readExpireTime,
       _refreshToken = refreshToken,
       _writeTokenSet = writeTokenSet,
       _now = now;

  /// 创建可注入时间、存储和 OAuth 网关的测试实例。
  BangumiTokenService.forTesting({
    required BangumiTokenReader readAccessToken,
    required BangumiTokenReader readRefreshToken,
    required BangumiExpireTimeReader readExpireTime,
    required BangumiTokenRefresher refreshToken,
    required BangumiTokenSetWriter writeTokenSet,
    DateTime Function()? now,
    Duration refreshAhead = BangumiTokenService.defaultRefreshAhead,
  }) : this._(
         readAccessToken: readAccessToken,
         readRefreshToken: readRefreshToken,
         readExpireTime: readExpireTime,
         refreshToken: refreshToken,
         writeTokenSet: writeTokenSet,
         now: now ?? DateTime.now,
         refreshAhead: refreshAhead,
       );

  BangumiTokenService._default()
    : this._(
        readAccessToken: () => BgmUserHive().tokenAC,
        readRefreshToken: () => BgmUserHive().tokenRF,
        readExpireTime: () => BgmUserHive().expireTime,
        refreshToken: BtrBangumiOauth().refreshToken,
        writeTokenSet:
            ({
              required accessToken,
              required refreshToken,
              required expiresIn,
            }) => BgmUserHive().updateTokenSet(
              accessToken: accessToken,
              refreshToken: refreshToken,
              expiresIn: expiresIn,
            ),
        now: DateTime.now,
      );

  final BangumiTokenReader _readAccessToken;
  final BangumiTokenReader _readRefreshToken;
  final BangumiExpireTimeReader _readExpireTime;
  final BangumiTokenRefresher _refreshToken;
  final BangumiTokenSetWriter _writeTokenSet;
  final DateTime Function() _now;

  /// 可配置的提前刷新窗口。
  final Duration refreshAhead;

  /// 当前正在进行的刷新请求。所有调用方共享同一个 Future。
  Future<BangumiTokenRefreshResult>? _refreshing;

  /// 刷新成功后的短期抑制点。
  ///
  /// 当 OAuth 返回的 Token 生命周期短于提前刷新窗口时，如果只看持久化过期
  /// 时间，刷新成功后会立刻再次满足“提前一天刷新”。在同一进程内至少等过半
  /// 个新 Token 生命周期，再重新应用提前刷新窗口；force 刷新不受此限制。
  DateTime? _refreshNotBefore;

  /// 与刷新抑制点对应的 access token，账号切换后旧抑制点自动失效。
  String? _refreshNotBeforeToken;

  /// 返回当前 Token 是否已经进入刷新窗口。
  bool get shouldRefresh {
    var accessToken = _readAccessToken();
    if (accessToken == null || accessToken.isEmpty) return true;

    var expireTime = _readExpireTime();
    if (expireTime == null) return true;

    var current = _now();
    if (!current.isBefore(expireTime)) return true;

    var notBefore = _refreshNotBefore;
    if (_refreshNotBeforeToken == accessToken &&
        notBefore != null &&
        current.isBefore(notBefore)) {
      return false;
    }

    var refreshAt = expireTime.subtract(refreshAhead);
    return !current.isBefore(refreshAt);
  }

  /// 在需要时刷新 Token，并保证同一时刻只有一个刷新请求。
  Future<BangumiTokenRefreshResult> ensureFresh({bool force = false}) {
    var current = _refreshing;
    if (current != null) return current;
    if (!force && !shouldRefresh) {
      return Future.value(BangumiTokenRefreshResult.notNeeded);
    }

    var refreshFuture = _refreshInternal();
    _refreshing = refreshFuture;
    return refreshFuture.whenComplete(() {
      if (identical(_refreshing, refreshFuture)) {
        _refreshing = null;
      }
    });
  }

  /// 请求前获取最新 access token。
  ///
  /// 刷新失败时仍返回内存中的旧 Token，让业务请求得到原始 401；401 处理器
  /// 会再次以 force 模式尝试一次，并在失败后透传错误。
  Future<String?> accessTokenForRequest() async {
    await ensureFresh();
    return _readAccessToken();
  }

  /// 返回当前内存中的 access token，用于识别其它请求是否已经完成轮换。
  String? get currentAccessToken => _readAccessToken();

  Future<BangumiTokenRefreshResult> _refreshInternal() async {
    var refreshToken = _readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      BTLogTool.warn('无 refreshToken，无法刷新');
      return BangumiTokenRefreshResult.unavailable;
    }

    try {
      var response = await _refreshToken(refreshToken);
      if (response.code != 0 ||
          response.data is! BangumiOauthTokenRefreshData) {
        BTLogTool.warn('Bangumi Token 刷新失败，响应码：${response.code}');
        return BangumiTokenRefreshResult.failed;
      }

      var data = response.data! as BangumiOauthTokenRefreshData;
      if (data.accessToken.isEmpty || data.refreshToken.isEmpty) {
        BTLogTool.warn('Bangumi Token 刷新失败，响应缺少凭据');
        return BangumiTokenRefreshResult.failed;
      }

      await _writeTokenSet(
        accessToken: data.accessToken,
        refreshToken: data.refreshToken,
        expiresIn: data.expiresIn,
      );
      _refreshNotBefore = _now().add(Duration(seconds: data.expiresIn ~/ 2));
      _refreshNotBeforeToken = data.accessToken;
      return BangumiTokenRefreshResult.refreshed;
    } catch (error, stackTrace) {
      BTLogTool.error([
        'Bangumi Token 刷新异常',
        error.toString(),
        stackTrace.toString(),
      ]);
      return BangumiTokenRefreshResult.failed;
    }
  }
}
