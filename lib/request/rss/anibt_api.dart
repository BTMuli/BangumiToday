// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../../models/app/response.dart';
import '../../models/rss/anibt_filters.dart';
import '../../models/rss/rss.dart';
import '../../tools/log_tool.dart';
import '../core/client.dart';

class AnibtAPI {
  late final BtrClient client;
  static const String baseUrl = 'https://anibt.net';
  static const String rssUrl = '$baseUrl/rss/magnets.xml';

  AnibtAPI() {
    client = BtrClient();
    client.dio.options.baseUrl = baseUrl;
  }

  Future<BTResponse> getMagnetsRSS({AnibtFilters? filters}) async {
    try {
      var resp = await client.dio.get<String>(
        rssUrl,
        queryParameters: filters?.queryParameters,
        options: Options(
          responseType: ResponseType.plain,
          listFormat: ListFormat.multi,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
      var channel = RssFeed.parse(resp.data ?? '');
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
