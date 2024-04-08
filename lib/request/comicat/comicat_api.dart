import 'package:dart_rss/domain/rss_feed.dart';
import 'package:dart_rss/domain/rss_item.dart';

import '../../models/app/err.dart';
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
  Future<List<RssItem>> getHomeRSS() async {
    var response = await client.dio.get('/rss.xml');
    if (response.statusCode != 200) {
      throw BTError.requestError(msg: 'Failed to load home RSS');
    }
    final channel = RssFeed.parse(response.data.toString());
    return channel.items;
  }
}
