// Package imports:
import 'package:dio/dio.dart';
import 'package:html/parser.dart';

// Project imports:
import '../../../request/core/client.dart';
import '../../core/source_model.dart';

/// 哔咪动漫的API
class BimiApi {
  /// 客户端
  late final BtrClient client;

  /// 是否初始化
  late bool isInit = false;

  /// 基础链接
  final baseUrl = 'https://www.bimiacg4.net';

  /// source
  final source = '哔咪动漫';

  /// 初始化
  Future<void> init() async {
    client = BtrClient.withHeader();
    client.dio.options.baseUrl = baseUrl;
    isInit = true;
  }

  /// 查找
  Future<List<BtSourceFind>> search(String keyword) async {
    if (!isInit) await init();
    var res = <BtSourceFind>[];
    try {
      var resp = await client.dio.post(
        '/vod/search/',
        data: {'wd': keyword},
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );
      var doc = parse(resp.data);
      var list = doc.querySelector('.drama-module')!.querySelectorAll('li');
      for (var div in list) {
        var anchor = div.querySelector('a')!;
        var id = anchor.attributes['href']!.split("/")[3];
        var name = anchor.attributes['title']!;
        var image = div.querySelector('img')?.attributes['data-original'];
        res.add(BtSourceFind(source, id, name, image: image));
      }
    } catch (e) {
      rethrow;
    }
    return res;
  }

  /// 解析
  Future<List<BtSource>> load(String series) async {
    var res = <BtSource>[];
    try {
      var resp = await client.dio.get('/bangumi/bi/$series');
      var doc = parse(resp.data);
      var list = doc.querySelector('#tab')!.querySelectorAll('a').asMap();
      for (var idx in list.keys) {
        var anchor = list[idx]!;
        var name = anchor.text;
        var episodes = <BtSourceEp>[];
        var epList = doc
            .querySelectorAll('.player_list')[idx]
            .querySelectorAll('li')
            .asMap();
        for (var idxE in epList.keys) {
          var li = epList[idxE]!;
          var epLink = li.querySelector('a')!.attributes['href']!;
          var epName = li.querySelector('a')!.text;
          episodes.add(BtSourceEp(idxE, episode: epLink, title: epName));
        }
        res.add(BtSource(episodes: episodes, name: name));
      }
    } catch (e) {
      rethrow;
    }
    return res;
  }

  /// 获取视频链接
  Future<String> play(String episode) async {
    try {
      var resp = await client.dio.get('/$episode');
      var doc = parse(resp.data);
      for (var script in doc.querySelectorAll('script')) {
        if (!script.text.contains('player_aaaa')) continue;
        for (var line in script.text.split(',')) {
          if (!line.contains('"url"')) continue;
          var link = line.split(':')[1].replaceAll('"', '').replaceAll(',', '');
          return parseLink(link, episode);
        }
      }
    } catch (e) {
      rethrow;
    }
    return '';
  }

  /// 解析链接
  Future<String> parseLink(String url, String episode) async {
    var link = '$baseUrl$episode';
    var params = {"url": url, "myurl": link};
    var resp = await client.dio.get(
      '/static/danmu/play.php',
      queryParameters: params,
    );
    var doc = parse(resp.data.toString());
    for (var script in doc.querySelectorAll('script')) {
      if (!script.text.contains('url')) continue;
      var line = script.text.trim().split('\n').first;
      var url = line.substring(line.indexOf("'") + 1, line.lastIndexOf("'"));
      if (url.contains('m3u8')) {
        var path = url.substring(1);
        return '$baseUrl$path';
      } else {
        return url;
      }
    }
    return '';
  }
}
