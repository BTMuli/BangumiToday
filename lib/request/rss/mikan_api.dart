// Package imports:
import 'package:dart_rss/dart_rss.dart';
import 'package:dio/dio.dart';

// Project imports:
import '../../models/app/response.dart';
import '../../tools/log_tool.dart';
import '../core/client.dart';

/// 蜜柑计划的API，主要是 rss 订阅
/// 站点：https://mikanani.me
/// 镜像站点：https://mikanani.hacgn.fun
class MikanAPI {
  /// 请求客户端
  late final BtrClient client;

  /// 基础 URL
  final String baseUrl = 'https://mikanime.tv/RSS';

  /// 构造函数
  MikanAPI() {
    client = BtrClient();
    client.dio.options.baseUrl = baseUrl;
  }

  /// 更新列表的 RSS
  Future<BTResponse> getClassicRSS() async {
    try {
      var resp = await client.dio.get('/Classic');
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
        '/MyBangumi',
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
