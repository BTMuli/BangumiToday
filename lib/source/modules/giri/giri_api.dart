// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:html/parser.dart';

// Project imports:
import '../../../request/core/client.dart';
import '../../core/source_model.dart';

/// GiriGiriLove的API
class GiriApi {
  /// 请求客户端
  late final BtrClient client;

  /// 基础URL
  final String baseUrl = 'https://anime.girigirilove.com';

  /// 构造函数
  GiriApi() {
    client = BtrClient.withHeader();
    client.dio.options.baseUrl = baseUrl;
  }

  /// 搜索关键词
  Future<List<BtSourceFind>> search(String keyword) async {
    var res = <BtSourceFind>[];
    var params = {'wd': keyword};
    try {
      var resp = await client.dio.get(
        '/search/-------------/',
        queryParameters: params,
      );
      var doc = parse(resp.data);
      var list = doc.getElementsByClassName('public-list-box');
      var regex = RegExp(r'url\((.*?)\)');
      for (var div in list) {
        var title = div.querySelector('.thumb-txt')!.text;
        var desc = div.querySelector('.thumb-blurb')!.text;
        String? image;
        var style = div.querySelector('.cover')?.attributes['style'];
        if (style != null && regex.firstMatch(style) != null) {
          var url = regex.firstMatch(style)!.group(1);
          image = baseUrl + url!;
        }
        var id = div
            .querySelector('.thumb-menu')!
            .firstChild!
            .attributes['href']!
            .replaceAll("/", "");
        res.add(BtSourceFind(id, title, desc: desc, image: image));
      }
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
    return res;
  }

  /// 解析播放链接
  Future<List<BtSource>> load(String series) async {
    var res = <BtSource>[];
    try {
      var resp = await client.dio.get(series);
      var doc = parse(resp.data);
      var links = doc.querySelectorAll('.anthology-list-play');
      for (var link in links) {
        var episodes = <BtSourceEp>[];
        var item = link.querySelectorAll('li').asMap();
        for (var idx in item.keys) {
          var li = item[idx]!;
          var ep = li.firstChild!.attributes['href']!.replaceAll("/", "");
          episodes.add(BtSourceEp(idx, episode: ep));
        }
        res.add(BtSource(episodes: episodes));
      }
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
    return res;
  }

  /// 获取播放链接
  Future<String> play(String episode) async {
    try {
      var resp = await client.dio.get(episode);
      var doc = parse(resp.data);
      var div =
          doc.querySelector('.play-left') ?? doc.querySelector('.player-top');
      var script =
          div!.querySelector('script')!.text.split(',').map((e) => e.trim());
      for (var line in script) {
        if (line.contains('"url"')) {
          var encode =
              line.split(":")[1].replaceAll('"', "").replaceAll(",", "");
          return Uri.decodeFull(String.fromCharCodes(base64Decode(encode)));
        }
      }
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
    return '';
  }
}
