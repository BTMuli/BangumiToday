import 'package:dart_rss/dart_rss.dart';
import 'package:dio/dio.dart';
import '../../models/app/response.dart';
import '../core/client.dart';

/// 蜜柑计划的API，主要是 rss 订阅
/// 站点：https://mikanani.me
/// 镜像站点：https://mikanani.hacgn.fun
class MikanAPI {
  /// 请求客户端
  late final BTRequestClient client;

  /// 基础 URL
  final String baseUrl = 'https://mikanime.tv/RSS';

  /// 构造函数
  MikanAPI() {
    client = BTRequestClient();
    client.dio.options.baseUrl = baseUrl;
  }

  /// 更新列表的 RSS
  Future<BTResponse> getClassicRSS() async {
    try {
      var resp = await client.dio.get('/Classic');
      final channel = RssFeed.parse(resp.data.toString());
      return BTResponse.success(data: channel.items);
    } on DioException catch (e) {
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load mikan classic RSS',
        data: e.response?.data,
      );
    } on Exception catch (e) {
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
      final channel = RssFeed.parse(resp.data.toString());
      return BTResponse.success(data: channel.items);
    } on DioException catch (e) {
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load user RSS',
        data: e.response?.data,
      );
    } on Exception catch (e) {
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
      /// 没有baseUrl
      var resp = await client.dio.get(url);
      final channel = RssFeed.parse(resp.data.toString());
      return BTResponse.success(data: channel);
    } on DioException catch (e) {
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load custom RSS',
        data: e.response?.data,
      );
    } on Exception catch (e) {
      return BTResponse.error(
        code: 666,
        message: 'Failed to load custom RSS',
        data: e.toString(),
      );
    }
  }
}
