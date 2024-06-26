// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../../models/app/response.dart';
import '../../models/source/danmaku_enum.dart';
import '../../models/source/request_danmaku.dart';
import '../../tools/log_tool.dart';
import '../core/client.dart';

/// DandanPlay 的 API，用于获取弹幕
/// 参考：https://api.dandanplay.net/swagger/ui/index
class BtrDanmakuAPI {
  /// 请求客户端
  late final BtrClient client;

  /// 基础 URL
  final String baseUrl = 'https://api.dandanplay.net/api/v2/';

  /// 构造函数
  BtrDanmakuAPI() {
    client = BtrClient.withHeader();
    client.dio.options.baseUrl = baseUrl;
  }

  /// 查找动画
  Future<BTResponse> searchAnime(
    String keyword, {
    DanmakuAnimeType? type,
  }) async {
    var param = {'keyword': keyword} as Map<String, dynamic>;
    if (type != null) {
      param['type'] = type.value;
    }
    try {
      var resp = await client.dio.get('/search/anime', queryParameters: param);
      var data = DanmakuSearchAnimeResponse.fromJson(resp.data);
      return data.toBTResponse();
    } on DioException catch (e) {
      var errInfo = [
        '[DanmakuAPI][SearchAnime][$keyword] DioException',
        'Params: $param',
        'DioErr: ${e.error}'
      ];
      BTLogTool.error(errInfo);
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to search danmaku anime $keyword',
        data: e.error,
      );
    } on Exception catch (e) {
      var errInfo = [
        '[DanmakuAPI][SearchAnime][$keyword] Exception',
        'Params: $param',
        'Err: ${e.toString()}'
      ];
      BTLogTool.error(errInfo);
      return BTResponse.error(
        code: 666,
        message: 'Failed to search danmaku anime $keyword',
        data: e.toString(),
      );
    }
  }

  /// 查找动画（精简版）
  Future<List<DanmakuSearchAnimeDetails>> searchAnime2(
    String keyword, {
    DanmakuAnimeType? type,
  }) async {
    var resp = await searchAnime(keyword, type: type);
    if (resp.code != 0 || resp.data == null) return [];
    if (resp.data is! List) return [];
    var list = resp.data as List;
    return list
        .map(
          (e) => DanmakuSearchAnimeDetails.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  /// 查找章节
  /// 如果 animeId 为 17441，则该 anime 下第一个 episode 为 174410001，第二个为 174410002
  /// 所以只需要获取 animeId 跟集数即可，不过还是需要支持手动切换
  Future<BTResponse> searchEpisode(String anime, {String episode = ''}) async {
    var param = {'anime': anime} as Map<String, dynamic>;
    if (episode.isNotEmpty) {
      param['episode'] = episode;
    }
    try {
      var resp = await client.dio.get(
        '/search/episodes',
        queryParameters: param,
      );
      var data = DanmakuSearchEpisodesResponse.fromJson(resp.data);
      return data.toBTResponse();
    } on DioException catch (e) {
      var errInfo = [
        '[DanmakuAPI][SearchEpisode][$anime] DioException',
        'Params: $param',
        'DioErr: ${e.error}'
      ];
      BTLogTool.error(errInfo);
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to search danmaku episode $anime',
        data: e.error,
      );
    } on Exception catch (e) {
      var errInfo = [
        '[DanmakuAPI][SearchEpisode][$anime] Exception',
        'Params: $param',
        'Err: ${e.toString()}'
      ];
      BTLogTool.error(errInfo);
      return BTResponse.error(
        code: 666,
        message: 'Failed to search danmaku episode $anime',
        data: e.toString(),
      );
    }
  }

  /// 查找章节（精简版）
  Future<List<DanmakuSearchEpisodesAnime>> searchEpisode2(String anime) async {
    var resp = await searchEpisode(anime);
    if (resp.code != 0 || resp.data == null) return [];
    if (resp.data is! List) return [];
    var list = resp.data as List;
    return list
        .map(
          (e) => DanmakuSearchEpisodesAnime.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  /// 获取弹幕
  /// [from] 为起始弹幕编号，忽略该编号之前的弹幕
  /// [related] 是否同时获取关联的第三方弹幕，默认为 false
  /// [convert] 中文简繁转换，0-不处理，1-简体，2-繁体
  Future<BTResponse> getDanmaku(
    int episode, {
    int? from,
    bool? related,
    int? convert,
  }) async {
    var param = {'episodeId': episode} as Map<String, dynamic>;
    if (from != null) {
      param['from'] = from;
    }
    if (related != null) {
      param['withRelated'] = related;
    }
    if (convert != null) {
      param['convert'] = convert;
    }
    try {
      var resp = await client.dio.get(
        '/comment/$episode',
        queryParameters: param,
      );
      var data = DanmakuEpisodeCommentsResponse.fromJson(resp.data);
      return data.toBTResponse();
    } on DioException catch (e) {
      var errInfo = [
        '[DanmakuAPI][GetDanmaku][$episode] DioException',
        'Params: $param',
        'DioErr: ${e.error}'
      ];
      BTLogTool.error(errInfo);
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to get danmaku $episode',
        data: e.error,
      );
    } on Exception catch (e) {
      var errInfo = [
        '[DanmakuAPI][GetDanmaku][$episode] Exception',
        'Params: $param',
        'Err: ${e.toString()}'
      ];
      BTLogTool.error(errInfo);
      return BTResponse.error(
        code: 666,
        message: 'Failed to get danmaku $episode',
        data: e.toString(),
      );
    }
  }

  /// 获取弹幕（精简版）
  Future<List<DanmakuEpisodeComment>> getDanmaku2(int episode) async {
    var resp = await getDanmaku(episode);
    if (resp.code != 0 || resp.data == null) return [];
    var data = resp.data as DanmakuEpisodeCommentsResponse;
    return data.comments;
  }
}
