// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/data/parsers/rss_parser.dart';
import 'package:bangumi_today/domain/rss/animegarden_query.dart';
import 'package:bangumi_today/domain/rss/feed_identity.dart';
import 'package:bangumi_today/models/database/app_subscription_model.dart';
import 'package:bangumi_today/models/rss/animegarden_resource.dart';
import 'package:bangumi_today/widgets/rss/rss_release_data.dart';

const _fixtures = 'test/rss_bmf/fixtures/animegarden';

Map<String, dynamic> fixture() =>
    jsonDecode(File('$_fixtures/resources.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('查询编码中文、重复参数和稳定顺序，GET 使用单数 keyword', () {
    var first = const AnimeGardenQuery(
      subjects: [543360, 42, 543360],
      search: ' 测试 番剧 ',
      include: ['应被忽略'],
      keywords: [' 简日 ', '1080p', '', '1080p'],
      exclude: ['合集', '720p'],
      fansub: '喵萌奶茶屋',
    ).resourceUri;
    var second = const AnimeGardenQuery(
      subjects: [42, 543360],
      search: '测试 番剧',
      keywords: ['1080p', '简日'],
      exclude: ['720p', '合集'],
      fansub: '喵萌奶茶屋',
    ).resourceUri;
    expect(first, second);
    expect(first.queryParametersAll['subject'], ['42', '543360']);
    expect(first.queryParametersAll['keyword'], ['1080p', '简日']);
    expect(first.queryParameters.containsKey('keywords'), isFalse);
    expect(first.queryParameters.containsKey('include'), isFalse);
    expect(first.queryParameters['fansub'], '喵萌奶茶屋');
    expect(first.queryParameters['tracker'], 'true');
  });

  test('include、来源、发布者、时间和分页参数正确传递', () {
    var query = AnimeGardenQuery(
      include: const ['别名 B', '别名 A'],
      keywords: const ['1080p'],
      exclude: const ['720p'],
      publisher: '发布者',
      provider: 'dmhy',
      page: 9,
      after: DateTime.utc(2026, 10),
      before: DateTime.utc(2026, 11),
    );
    var uri = query.resourceUri;
    expect(uri.path, '/resources');
    expect(uri.queryParametersAll['include'], ['别名 A', '别名 B']);
    expect(uri.queryParameters['page'], '9');
    expect(uri.queryParameters['pageSize'], '50');
    expect(
      uri.queryParameters['after'],
      DateTime.utc(2026, 10).toIso8601String(),
    );
    expect(
      uri.queryParameters['before'],
      DateTime.utc(2026, 11).toIso8601String(),
    );
    expect(uri.queryParameters['publisher'], '发布者');
    expect(uri.queryParameters['provider'], 'dmhy');
    expect(query.atPage(2).resourceUri.queryParameters['page'], '2');
  });

  test('类型支持预设、自定义及全部类型，翻页保留所选类型', () {
    for (var type in ['', '动画', '漫画', '音乐', '游戏', '演唱会 / 特典&字幕']) {
      var query = AnimeGardenQuery(type: ' $type ');
      expect(
        query.resourceUri.queryParameters['type'],
        type.isEmpty ? null : type,
      );
      expect(
        query.atPage(2).resourceUri.queryParameters['type'],
        type.isEmpty ? null : type,
      );
      expect(query.atPage(2).resourceUri.queryParameters['page'], '2');
    }
    expect(const AnimeGardenQuery().resourceUri.queryParameters['type'], '动画');
  });

  test('官方 JSON 保留原始信息、字节和时区，tracker 不重复编码', () {
    var page = AnimeGardenPage.fromJson(fixture());
    expect(page.resources, isNotEmpty);
    expect(page.pagination.complete, isFalse);
    var resource = page.resources.first;
    expect(resource.createdAt.isUtc, isTrue);
    var release = RssReleaseData.fromAnimeGarden(resource);
    expect(release.title, resource.title);
    expect(release.item.enclosure!.length, resource.size);
    expect(release.publishedAt, resource.createdAt);
    expect(release.downloadUrl, '${resource.magnet}${resource.tracker ?? ''}');
    expect(release.detailUrl, contains('/detail/${resource.provider}/'));
    expect(release.originUrl, resource.href);
    expect(resource.subjectId, 543360);
    expect(release.item.subjectId, isNull);
    expect(release.tags, contains('上游关联 Bangumi 543360（未核验）'));
    expect(release.tags, contains('字幕组 ${resource.fansub!.name}'));
    expect(release.author, resource.publisher.name);
    expect(AnimeGardenPage.fromJson(page.toJson()).resources.length, 2);
  });

  test('魔王大人被上游 MAO 规则误关联时，不向下载任务传递摩绪 ID', () {
    // Public resources: /detail/dmhy/727611 and /detail/dmhy/616958.
    const titles = [
      '[7³ACG] 打工吧！魔王大人/Hataraku Maousama! S01 | '
          '01-13 [简繁字幕] BDrip 1080p AV1 OPUS 2.0',
      '[动漫国字幕组&LoliHouse] 打工吧!! 魔王大人 / '
          'Hataraku Maou-sama S2 [01-12 修正合集]'
          '[WebRip 1080p HEVC-10bit AAC][简繁外挂字幕][Fin]',
    ];
    for (var title in titles) {
      var raw = (fixture()['resources'] as List).first as Map<String, dynamic>;
      raw['title'] = title;
      raw['subjectId'] = 570448;
      var resource = AnimeGardenResource.fromJson(raw);
      var release = RssReleaseData.fromAnimeGarden(resource);
      expect(resource.toJson()['subjectId'], 570448);
      expect(release.item.subjectId, isNull);
      expect(release.tags, contains('上游关联 Bangumi 570448（未核验）'));
      expect(release.tags, isNot(contains('Bangumi 570448')));
      expect(release.canDownload, isTrue);
    }
  });

  test('缺少关联和字幕组、空 metadata、大小为零均合法', () {
    var raw = (fixture()['resources'] as List).first as Map<String, dynamic>;
    raw.remove('subjectId');
    raw.remove('fansub');
    raw.remove('tracker');
    raw['metadata'] = <String, dynamic>{};
    raw['size'] = 0;
    raw['createdAt'] = '2026-10-29T12:00:00+08:00';
    var resource = AnimeGardenResource.fromJson(raw);
    var release = RssReleaseData.fromAnimeGarden(resource);
    expect(resource.createdAt, DateTime.utc(2026, 10, 29, 4));
    expect(resource.metadata, isEmpty);
    expect(release.item.subjectId, isNull);
    expect(release.tags.any((tag) => tag.startsWith('字幕组')), isFalse);
    expect(release.downloadUrl, resource.magnet);
    expect(release.sizeLabel, isNotNull);
  });

  test('业务错误与空列表区分，分页结束由 complete 决定', () {
    expect(
      () => AnimeGardenPage.fromJson({'status': 'ERROR'}),
      throwsFormatException,
    );
    var page = AnimeGardenPage.fromJson({
      'status': 'OK',
      'resources': [],
      'pagination': {'page': 2, 'pageSize': 50, 'complete': false},
    });
    expect(page.resources, isEmpty);
    expect(page.pagination.complete, isFalse);
  });

  test('手动 Anime Garden RSS 沿用通用解析，不启用专用条目关联', () {
    for (var hash in [
      'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567',
      '0123456789abcdef0123456789abcdef01234567',
    ]) {
      var magnet = 'magnet:?xt=urn:btih:$hash';
      var item = RssFeed.parse('''
<rss xmlns:ag="https://animes.garden/ns/rss/1.0"><channel><item>
<title>测试</title><ag:subjectId>42</ag:subjectId>
<pubDate>Fri, 30 Oct 2026 00:00:00 GMT</pubDate>
<enclosure url="$magnet"/>
</item></channel></rss>''').items.single;
      expect(item.subjectId, isNull);
      var release = RssReleaseData.fromItem(item, RssReleaseSource.generic);
      expect(release.downloadUrl, magnet);
      expect(release.publishedAt, DateTime.utc(2026, 10, 30));
    }
  });

  test('自定义 RSS 仍属 generic，来源回退不改订阅键、基线、未读或待核对状态', () {
    const url =
        'https://api.animes.garden/feed.xml?subject=42&keyword=a'
        '&keyword=b';
    var identity = FeedIdentity.fromUrl(url);
    expect(identity.provider, 'generic');
    expect(
      identity.feedKey,
      'rss:v1:${sha256.convert(utf8.encode(jsonEncode([url, ''])))}',
    );
    expect(
      FeedIdentity.fromUrl(
        'https://api.animes.garden/collection/abc/feed.xml',
      ).provider,
      'generic',
    );
    expect(
      RssReleaseSource.fromProvider('animegarden'),
      RssReleaseSource.generic,
    );
    for (var provider in ['generic', 'animegarden']) {
      var old = AppSubscriptionModel(
        provider: provider,
        url: url,
        feedKey: identity.feedKey,
        pendingItems: '["pending"]',
        knownItems: '["known"]',
        hasBaseline: true,
        status: 'needsReview',
      );
      var saved = old.copyWith();
      expect(saved.provider, 'generic');
      expect(saved.feedKey, old.feedKey);
      expect(saved.pendingItems, old.pendingItems);
      expect(saved.knownItems, old.knownItems);
      expect(saved.hasBaseline, isTrue);
      expect(saved.status, 'needsReview');
      expect(saved.itemKeyVersion, old.itemKeyVersion);
      expect(saved.canRefresh, isFalse);
    }
  });
}
