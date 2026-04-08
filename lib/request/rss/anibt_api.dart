import 'package:dart_rss/domain/rss_feed.dart';
import 'package:dio/dio.dart';

import '../../models/app/response.dart';
import '../../tools/log_tool.dart';
import '../core/client.dart';

class AnibtAPI {
  late final BtrClient client;
  final String baseUrl = 'https://anibt.net';

  AnibtAPI() {
    client = BtrClient();
    client.dio.options.baseUrl = baseUrl;
  }

  Future<BTResponse> getMagnetsRSS() async {
    try {
      var resp = await client.dio.get('/rss/magnets.xml');
      var channel = RssFeed.parse(resp.data.toString());
      return BTResponse.success(data: channel.items);
    } on DioException catch (e) {
      BTLogTool.error('Failed to load anibt RSS ${e.response?.data}');
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load anibt RSS',
        data: e.response?.data,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to load anibt RSS ${e.toString()}');
      return BTResponse.error(
        code: 666,
        message: 'Failed to load anibt RSS',
        data: e.toString(),
      );
    }
  }
}
