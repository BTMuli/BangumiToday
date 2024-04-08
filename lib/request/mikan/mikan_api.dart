import 'package:dart_rss/dart_rss.dart';
import 'package:fluent_ui/fluent_ui.dart';

import '../../models/app/err.dart';
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
  Future<List<RssItem>> getClassicRSS() async {
    var response = await client.dio.get('/Classic');
    if (response.statusCode != 200) {
      throw BTError.requestError(msg: 'Failed to load classic RSS');
    }
    final channel = RssFeed.parse(response.data.toString());
    return channel.items;
  }

  /// 获取用户的 RSS
  Future<List<RssItem>> getUserRSS(String token) async {
    var response = await client.dio.get(
      '/MyBangumi',
      queryParameters: {'token': token},
    );
    if (response.statusCode != 200) {
      throw BTError.requestError(msg: 'Failed to load user RSS');
    }
    debugPrint(response.data);
    final channel = RssFeed.parse(response.data.toString());
    return channel.items;
  }
}
