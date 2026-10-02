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
  var rss = mikanBangumiRssUrl(baseUrl: baseUrl, bangumiId: id);
  var title = li.querySelector(".an-text")?.attributes['title'];
  if (title == null) return null;
  var cover = _parseSearchCover(li, baseUrl);
  return MikanSearchItemModel(
    title: title,
    link: link,
    cover: cover,
    id: id,
    rss: rss,
  );
}

/// 番剧 RSS 地址，可按字幕组过滤
String mikanBangumiRssUrl({
  required String baseUrl,
  required String bangumiId,
  String? groupId,
}) {
  var rss = '$baseUrl/RSS/Bangumi?bangumiId=$bangumiId';
  if (groupId != null && groupId.isNotEmpty) rss += '&subgroupid=$groupId';
  return rss;
}

/// 解析搜索结果的封面
String _parseSearchCover(dom.Element li, String baseUrl) {
  var source = li.querySelector('.b-lazy.b-loaded');
  source ??= li.querySelector('.b-lazy');
  var cover =
      source?.attributes['data-src'] ?? source?.attributes['background-image'];
  if (cover == null || cover.isEmpty) return '';
  cover = cover.split('?').first;
  if (cover.startsWith('url(')) cover = cover.substring(4);
  cover = cover.replaceAll('"', '').replaceAll("'", '');
  if (cover.isEmpty) return '';
  if (cover.startsWith('http')) return cover;
  return baseUrl + cover;
}

/// 解析番剧详情页，返回字幕组列表与各字幕组的最近资源
MikanBangumiDetailModel parseBangumiDetail(
  String html,
  String baseUrl,
  String bangumiId,
) {
  var document = parse(html);
  var groups = <String, MikanGroupModel>{};
  var order = <String>[];
  for (var li in document.querySelectorAll('.leftbar-nav li.leftbar-item')) {
    var name = li.querySelector('a.subgroup-name');
    if (name == null) continue;
    var id = _parseGroupId(name);
    if (id == null) continue;
    var date = li.querySelector('span.date')?.text.trim();
    order.add(id);
    groups[id] = MikanGroupModel(
      id: id,
      name: name.text.trim(),
      rss: mikanBangumiRssUrl(
        baseUrl: baseUrl,
        bangumiId: bangumiId,
        groupId: id,
      ),
      updatedAt: date == null || date.isEmpty ? null : date,
    );
  }
  for (var table in document.querySelectorAll('div.episode-table')) {
    var id = _parseTableGroupId(table);
    if (id == null) continue;
    var items = _parseEpisodes(table, baseUrl);
    var existed = groups[id];
    if (existed != null) {
      groups[id] = existed.withItems(items);
      continue;
    }
    // 左侧列表缺失时，使用表格上方的字幕组标题兜底。
    var header = table.previousElementSibling;
    while (header != null && !header.classes.contains('subgroup-text')) {
      header = header.previousElementSibling;
    }
    var name = header?.querySelector('span')?.text.trim();
    order.add(id);
    groups[id] = MikanGroupModel(
      id: id,
      name: name == null || name.isEmpty ? id : name,
      rss: mikanBangumiRssUrl(
        baseUrl: baseUrl,
        bangumiId: bangumiId,
        groupId: id,
      ),
      items: items,
    );
  }
  return MikanBangumiDetailModel(
    id: bangumiId,
    bgmId: _parseBgmId(document),
    groups: order.map((id) => groups[id]).whereType<MikanGroupModel>().toList(),
  );
}

/// Bangumi 番组计划链接中的条目 ID
int? _parseBgmId(dom.Document document) {
  for (var a in document.querySelectorAll('a.w-other-c')) {
    var href = a.attributes['href'];
    if (href == null || !href.contains('bgm.tv/subject/')) continue;
    var id = href.split('bgm.tv/subject/').last.split('/').first;
    var parsed = int.tryParse(id);
    if (parsed != null && parsed > 0) return parsed;
  }
  return null;
}

/// 字幕组 ID，例如 `subgroup-name subgroup-243`
String? _parseGroupId(dom.Element element) {
  for (var name in element.classes) {
    if (!name.startsWith('subgroup-')) continue;
    var id = name.substring('subgroup-'.length);
    if (id.isEmpty || int.tryParse(id) == null) continue;
    return id;
  }
  var anchor = element.attributes['data-anchor'];
  if (anchor != null && anchor.length > 1) return anchor.substring(1);
  return null;
}

/// 资源表格所属的字幕组 ID（表格前的 `subgroup-text` 标题）
String? _parseTableGroupId(dom.Element table) {
  var sibling = table.previousElementSibling;
  while (sibling != null) {
    if (sibling.classes.contains('subgroup-text')) {
      var id = sibling.id;
      return id.isEmpty ? null : id;
    }
    if (sibling.classes.contains('episode-table')) return null;
    sibling = sibling.previousElementSibling;
  }
  return null;
}

/// 解析单个字幕组的资源表格
List<MikanEpisodeModel> _parseEpisodes(dom.Element table, String baseUrl) {
  var result = <MikanEpisodeModel>[];
  for (var tr in table.querySelectorAll('tbody tr')) {
    var link = tr.querySelector('a.magnet-link-wrap');
    if (link == null) continue;
    var title = link.text.trim();
    if (title.isEmpty) continue;
    var href = link.attributes['href'] ?? '';
    var magnet =
        tr
            .querySelector('input.js-episode-select')
            ?.attributes['data-magnet'] ??
        tr.querySelector('a.js-magnet')?.attributes['data-clipboard-text'] ??
        '';
    var torrent = tr.querySelector('a[href*="/Download/"]')?.attributes['href'];
    var cells = tr.querySelectorAll('td');
    var size = cells.length > 2 ? cells[2].text.trim() : '';
    var updatedAt = cells.length > 3 ? cells[3].text.trim() : '';
    result.add(
      MikanEpisodeModel(
        title: title,
        link: href.isEmpty ? '' : baseUrl + href,
        magnet: magnet.trim(),
        torrent: torrent == null || torrent.isEmpty ? null : baseUrl + torrent,
        size: size.isEmpty ? null : size,
        updatedAt: updatedAt.isEmpty ? null : updatedAt,
      ),
    );
  }
  return result;
}
