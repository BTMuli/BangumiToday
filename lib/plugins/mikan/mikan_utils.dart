// Package imports:
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';

// Project imports:
import 'models/mikan_model.dart';

/// 解析搜索结果返回的 html，获取搜索结果列表
List<MikanSearchItemModel> parseSearchResult(String html, String baseUrl) {
  var document = parse(html);
  var item = document.querySelector('.list-inline.an-ul');
  if (item == null) return [];
  var list = item.querySelectorAll('li');
  return list
      .map((e) => parseSearchItem(e, baseUrl))
      .where((element) => element != null)
      .map((e) => e!)
      .toList();
}

/// 解析搜索结果的li，返回搜索结果
MikanSearchItemModel? parseSearchItem(dom.Element li, String baseUrl) {
  var a = li.querySelector('a');
  if (a == null) return null;
  var link = a.attributes['href'];
  if (link == null) return null;
  var id = link.split('/').last;
  link = baseUrl + link;
  var rss = '$baseUrl/RSS/Bangumi?bangumiId=$id';
  var title = li.querySelector(".an-text")?.attributes['title'];
  if (title == null) return null;
  var cover = a
      .querySelector(".b-lazy.b-loaded")
      ?.attributes['background-image'];
  if (cover != null) {
    cover = cover.split('?').first;
    cover = cover.substring(5);
    cover = baseUrl + cover;
  }
  return MikanSearchItemModel(
    title: title,
    link: link,
    cover: cover ?? '',
    id: id,
    rss: rss,
  );
}
