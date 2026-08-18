// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../../core/constants/app_constants.dart';
import '../../models/app/response.dart';
import '../../models/rss/rss.dart';
import '../../request/core/client.dart';
import '../../tools/log_tool.dart';
import 'mikan_utils.dart';

/// 蜜柑计划的API，主要是 rss 订阅
/// 站点：https://mikanani.kas.pub
class BtrMikanApi {
  static String _baseUrl = BTAppConstants.defaultMikanMirror;

  /// 请求客户端
  late final BtrClient client;

  /// 当前镜像 URL
  static String get baseUrl => _baseUrl;

  /// 将已知 Mikan 站点 URL 改写为当前镜像
  static String rewriteUrl(String value) {
    return BTAppConstants.rewriteMikanUrl(value, baseUrl);
  }

  /// 更新基础 URL
  static void setBaseUrl(String value) {
    _baseUrl = BTAppConstants.normalizeMikanUrl(value);
  }

  /// 构造函数
  BtrMikanApi() {
    client = BtrClient();
    client.dio.options.baseUrl = baseUrl;
    client.dio.interceptors.insert(0, _MikanBaseUrlInterceptor());
  }

  /// 更新列表的 RSS
  Future<BTResponse> getClassicRSS() async {
    try {
      var resp = await client.dio.get('/RSS/Classic');
      var channel = RssFeed.parse(resp.data.toString());
      return BTResponse.success(data: channel.items);
    } on DioException catch (e) {
      var errInfo = ["Fail to load mikan classic RSS", "DioErr: ${e.error}"];
      BTLogTool.error(errInfo);
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load mikan classic RSS',
        data: e.error,
      );
    } on Exception catch (e) {
      var errInfo = ["Fail to load mikan classic RSS", "Err: ${e.toString()}"];
      BTLogTool.error(errInfo);
      return BTResponse.error(
        code: 666,
        message: 'Failed to load mikan classic RSS',
        data: e.toString(),
      );
    }
  }

  /// 获取用户的 RSS
  Future<BTResponse> getUserRSS(String token) async {
    try {
      var resp = await client.dio.get(
        '/RSS/MyBangumi',
        queryParameters: {'token': token},
      );
      var channel = RssFeed.parse(resp.data.toString());
      return BTResponse.success(data: channel.items);
    } on DioException catch (e) {
      var errInfo = ["Fail to load user RSS", "DioErr: ${e.error}"];
      BTLogTool.error(errInfo);
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load user RSS',
        data: {'error': e.error},
      );
    } on Exception catch (e) {
      var errInfo = ["Fail to load user RSS", "Err: ${e.toString()}"];
      BTLogTool.error(errInfo);
      return BTResponse.error(
        code: 666,
        message: 'Failed to load user RSS',
        data: e.toString(),
      );
    }
  }

  /// 查询
  Future<BTResponse> searchBgm(String search) async {
    try {
      var resp = await client.dio.get(
        '/Home/Search',
        queryParameters: {'searchstr': search},
      );
      var parseList = parseSearchResult(resp.data, baseUrl);
      return BTResponse.success(data: parseList);
    } on DioException catch (e) {
      var errInfo = [
        "Fail to search bgm",
        "DioErr: ${e.error}",
        "Search: $search",
      ];
      BTLogTool.error(errInfo);
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to search bgm',
        data: {'error': e.error, 'search': search},
      );
    } on Exception catch (e) {
      var errInfo = [
        "Fail to search bgm",
        "Err: ${e.toString()}",
        "Search: $search",
      ];
      BTLogTool.error(errInfo);
      return BTResponse.error(
        code: 666,
        message: 'Failed to search bgm',
        data: e.toString(),
      );
    }
  }

  /// 获取自定义 RSS
  Future<BTResponse> getCustomRSS(
    String url, {
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) async {
    var fetchUrl = rewriteUrl(url);
    try {
      var resp = await client.dio.get(
        fetchUrl,
        options: Options(
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
        ),
      );
      return BTResponse.success(data: resp.data);
    } on DioException catch (e) {
      var errInfo = ["Fail to load custom RSS $url", "DioErr: ${e.error}"];
      BTLogTool.error(errInfo);
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load custom RSS',
        data: e.error,
      );
    } on Exception catch (e) {
      var errInfo = ["Fail to load custom RSS $url", "Err: ${e.toString()}"];
      BTLogTool.error(errInfo);
      return BTResponse.error(
        code: 666,
        message: 'Failed to load custom RSS',
        data: e.toString(),
      );
    }
  }
}

class _MikanBaseUrlInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.baseUrl = BtrMikanApi.baseUrl;
    handler.next(options);
  }
}
