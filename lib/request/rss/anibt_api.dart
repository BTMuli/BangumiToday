// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../../models/app/response.dart';
import '../../models/rss/anibt_filters.dart';
import '../../models/rss/anibt_search.dart';
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

  /// https://wiki.anibt.net/docs/open-api/rss-anime.md
  static String animeRssUrl({required int bgmId, String? groupSlug}) =>
      Uri.parse('$baseUrl/rss/anime.xml')
          .replace(
            queryParameters: {
              'bgmId': bgmId.toString(),
              if (groupSlug != null && groupSlug.isNotEmpty)
                'groupSlug': groupSlug,
            },
          )
          .toString();

  /// https://wiki.anibt.net/docs/open-api/bgm-search.md
  Future<BTResponse<List<AnibtSearchItem>>> searchAnime(String query) =>
      _getData(
        '/api/bgm/search',
        {'q': query.trim(), 'limit': 25},
        (data) => (data as List)
            .map(
              (item) => AnibtSearchItem.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );

  /// https://wiki.anibt.net/docs/open-api/torrent.md
  static String releaseTorrentUrl(String releaseId) => Uri.parse(
    baseUrl,
  ).replace(pathSegments: ['api', 'torrent', '$releaseId.torrent']).toString();

  /// https://wiki.anibt.net/docs/open-api/anime-groups.md
  Future<BTResponse<List<AnibtAnimeGroup>>> getAnimeGroups(int bgmId) =>
      _getData(
        '/api/anime/groups',
        {'bgmId': bgmId},
        (data) => ((data as Map<String, dynamic>)['groups'] as List)
            .map(
              (item) => AnibtAnimeGroup.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );

  Future<BTResponse<T>> _getData<T>(
    String path,
    Map<String, dynamic> parameters,
    T Function(dynamic data) parse,
  ) async {
    try {
      var response = await client.dio.get<Map<String, dynamic>>(
        path,
        queryParameters: parameters,
        options: Options(
          responseType: ResponseType.json,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
      var body = response.data!;
      if (body['ok'] != true) {
        return BTResponse.error(
          code: 666,
          message: _errorMessage(body) ?? 'AniBT 请求失败',
          data: null,
        );
      }
      return BTResponse.success(data: parse(body['data']));
    } on DioException catch (error) {
      var status = error.response?.statusCode;
      var message = _errorMessage(error.response?.data) ?? '请稍后重试';
      BTLogTool.error('AniBT $path 请求失败：$status $message');
      return BTResponse.error(
        code: status ?? 666,
        message: 'AniBT 请求失败${status == null ? '' : '（HTTP $status）'}：$message',
        data: null,
      );
    } catch (error) {
      BTLogTool.error('AniBT $path 响应解析失败：$error');
      return BTResponse.error(
        code: 666,
        message: '无法读取 AniBT 响应，请稍后重试',
        data: null,
      );
    }
  }

  static String? _errorMessage(dynamic body) {
    if (body is! Map || body['error'] is! Map) return null;
    var message = (body['error'] as Map)['message'];
    return message is String ? message : null;
  }

  Future<BTResponse> getMagnetsRSS({AnibtFilters? filters}) async {
    try {
      var resp = await client.dio.get<String>(
        rssUrl,
        queryParameters: filters?.queryParameters,
        options: Options(
          responseType: ResponseType.plain,
          listFormat: ListFormat.multi,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
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
        message:
            e.response?.statusCode == 503 &&
                e.response?.data is String &&
                (e.response!.data as String).contains(
                  'Search backend unavailable',
                )
            ? 'AniBT 站点搜索暂不可用，请稍后重试'
            : 'AniBT 资源请求失败，请稍后重试',
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
