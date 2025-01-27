// Package imports:
import 'package:dart_rss/dart_rss.dart';
import 'package:dio/dio.dart';

// Project imports:
import '../../database/app/app_config.dart';
import '../../models/app/response.dart';
import '../../request/core/client.dart';
import '../../tools/log_tool.dart';
import 'mikan_utils.dart';

const String defaultMikanMirror = 'https://mikanani.me';

/// 蜜柑计划的API，主要是 rss 订阅
/// 站点：https://mikanani.me
class BtrMikanApi {
  /// 请求客户端
  late final BtrClient client;

  final BtsAppConfig sqlite = BtsAppConfig();

  /// 基础 URL
  final String baseUrl = defaultMikanMirror;

  /// 构造函数
  BtrMikanApi() {
    client = BtrClient();
    client.dio.options.baseUrl = baseUrl;
  }

  /// 检测baseUrl
  Future<void> getBaseUrl() async {
    var mkUrl = await sqlite.readMikanUrl();
    if (mkUrl != null && mkUrl.isNotEmpty) {
      client.dio.options.baseUrl = mkUrl;
    }
  }

  /// 更新列表的 RSS
  Future<BTResponse> getClassicRSS() async {
    await getBaseUrl();
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
    await getBaseUrl();
    try {
      var resp = await client.dio.get(
        '/RSS/MyBangumi',
        queryParameters: {'token': token},
      );
      var channel = RssFeed.parse(resp.data.toString());
      return BTResponse.success(data: channel.items);
    } on DioException catch (e) {
      var errInfo = [
        "Fail to load user RSS",
        "DioErr: ${e.error}",
        "UserToken: $token",
      ];
      BTLogTool.error(errInfo);
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load user RSS',
        data: {'error': e.error, 'token': token},
      );
    } on Exception catch (e) {
      var errInfo = [
        "Fail to load user RSS",
        "Err: ${e.toString()}",
        "UserToken: $token",
      ];
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
    await getBaseUrl();
    try {
      var resp = await client.dio.get(
        '/Home/Search',
        queryParameters: {'searchstr': search},
      );
      var parseList = parseSearchResult(resp.data, client.dio.options.baseUrl);
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
  Future<BTResponse> getCustomRSS(String url) async {
    try {
      var resp = await client.dio.get(url);
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
