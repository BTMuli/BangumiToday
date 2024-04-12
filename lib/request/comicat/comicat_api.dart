import 'package:dart_rss/domain/rss_feed.dart';
import 'package:dio/dio.dart';

import '../../models/app/response.dart';
import '../core/client.dart';

/// 漫猫动漫的API。主要是 rss 订阅
/// 站点：https://www.comicat.org
class ComicatAPI {
  /// 请求客户端
  late final BTRequestClient client;

  /// 基础 URL
  final String baseUrl = 'https://www.comicat.org';

  /// 构造函数
  ComicatAPI() {
    client = BTRequestClient();
    client.dio.options.baseUrl = baseUrl;
  }

  /// 获取首页的 RSS
  Future<BTResponse> getHomeRSS() async {
    try {
      var resp = await client.dio.get('/rss.xml');
      final channel = RssFeed.parse(resp.data.toString());
      return BTResponse.success(data: channel.items);
    } on DioException catch (e) {
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load comicat RSS',
        data: e.response?.data,
      );
    } on Exception catch (e) {
      return BTResponse.error(
        code: 666,
        message: 'Failed to load comicat RSS',
        data: e.toString(),
      );
    }
  }
}
