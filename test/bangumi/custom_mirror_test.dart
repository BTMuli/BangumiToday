// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/constants/app_constants.dart';
import 'package:bangumi_today/models/app/bangumi_mirror.dart';
import 'package:bangumi_today/request/bangumi/bangumi_api.dart';
import 'package:bangumi_today/request/bangumi/bangumi_oauth.dart';

void main() {
  late String apiUrl;
  late String siteUrl;
  late String imageUrl;
  late BangumiMirrorCatalog originalCatalog;

  setUp(() {
    apiUrl = BtrBangumiApi.baseUrl;
    siteUrl = BtrBangumiApi.siteBaseUrl;
    imageUrl = BtrBangumiApi.imageBaseUrl;
    originalCatalog = BtrBangumiApi.mirrorCatalog;
  });
  tearDown(() {
    BtrBangumiApi.setBaseUrl(apiUrl);
    BtrBangumiApi.setSiteBaseUrl(siteUrl);
    BtrBangumiApi.setImageBaseUrl(imageUrl);
    BtrBangumiApi.setMirrorCatalog(originalCatalog);
  });

  test('bgmapi is an independent API-only built-in mirror', () {
    var mirrors = BangumiMirrorType.api.builtIns;
    expect(
      mirrors.singleWhere((mirror) => mirror.name == 'bgm.tv（官方）').url,
      'https://api.bgm.tv',
    );
    expect(
      mirrors.singleWhere((mirror) => mirror.name == 'bgmapi.com').url,
      'https://api.bgmapi.com',
    );
    expect(BangumiMirrorType.api.defaultUrl, 'https://api.bgm.tv');
    expect(
      BangumiMirrorType.api.normalize('  https://api.bgmapi.com/  '),
      'https://api.bgmapi.com',
    );
    BtrBangumiApi.setBaseUrl('  https://api.bgmapi.com/  ');
    expect(BtrBangumiApi.baseUrl, 'https://api.bgmapi.com');
    for (var type in [BangumiMirrorType.site, BangumiMirrorType.image]) {
      expect(
        type.builtIns.any((mirror) => mirror.name == 'bgmapi.com'),
        isFalse,
      );
    }
  });

  test('mirror names and origins normalize without losing HTTP or ports', () {
    var mirror = BangumiMirror(
      name: '  自建镜像  ',
      url: '  HTTP://Localhost:8080/  ',
    );
    expect(mirror.name, '自建镜像');
    expect(mirror.url, 'http://localhost:8080');
    expect(
      BangumiMirror(name: 'IPv6', url: 'http://[::1]:8080').url,
      'http://[::1]:8080',
    );
    expect(
      BangumiMirror(name: '默认端口', url: 'https://EXAMPLE.test:443/').url,
      'https://example.test',
    );
  });

  test('invalid origins cannot become custom mirrors', () {
    for (var url in [
      '',
      'example.test',
      'file:///C:/mirror',
      'ftp://example.test',
      'https://user:password@example.test',
      'https://example.test/api',
      'https://example.test?token=secret',
      'https://example.test#fragment',
      'https://example.test:0',
      'https://example.test:65536',
      'https://example .test',
    ]) {
      expect(
        () => BangumiMirror(name: '镜像', url: url),
        throwsFormatException,
        reason: url,
      );
    }
    expect(
      () => BangumiMirror(name: ' ', url: 'https://example.test'),
      throwsFormatException,
    );
  });

  test('custom entries are independent and built-ins stay protected', () {
    var mirror = BangumiMirror(name: '自建', url: 'https://mirror.example.test');
    var catalog = const BangumiMirrorCatalog().save(
      BangumiMirrorType.site,
      mirror,
    );
    expect(catalog.entries(BangumiMirrorType.site).single.url, mirror.url);
    expect(catalog.entries(BangumiMirrorType.api), isEmpty);
    expect(catalog.entries(BangumiMirrorType.image), isEmpty);
    for (var type in BangumiMirrorType.values) {
      for (var builtIn in type.builtIns) {
        expect(() => catalog.save(type, builtIn), throwsFormatException);
        expect(() => catalog.remove(type, builtIn.url), throwsFormatException);
        expect(
          () => catalog.save(type, mirror, originalUrl: builtIn.url),
          throwsFormatException,
        );
      }
    }
  });

  test('duplicate names, normalized origins and built-ins are rejected', () {
    var mirror = BangumiMirror(name: '自建', url: 'https://mirror.example.test');
    var catalog = const BangumiMirrorCatalog().save(
      BangumiMirrorType.api,
      mirror,
    );
    for (var duplicate in [
      BangumiMirror(name: '另一个', url: 'https://MIRROR.example.test:443/'),
      BangumiMirror(name: '自建', url: 'https://other.example.test'),
      BangumiMirror(name: '旧官方', url: 'https://api.bgm.tv'),
      BangumiMirror(name: '独立 API', url: 'https://api.bgmapi.com'),
    ]) {
      expect(
        () => catalog.save(BangumiMirrorType.api, duplicate),
        throwsFormatException,
      );
    }
  });

  test('edit and delete retain old origins across JSON round trips', () {
    var old = BangumiMirror(name: '原镜像', url: 'http://old.example.test:8080');
    var next = BangumiMirror(name: '新镜像', url: 'https://new.example.test');
    var catalog = const BangumiMirrorCatalog().save(
      BangumiMirrorType.image,
      old,
    );
    catalog = catalog.save(BangumiMirrorType.image, next, originalUrl: old.url);
    expect(catalog.entries(BangumiMirrorType.image).single.name, '新镜像');
    expect(catalog.knownUrls(BangumiMirrorType.image), contains(old.url));
    catalog = catalog.remove(BangumiMirrorType.image, next.url);
    var restored = BangumiMirrorCatalog.fromJson(
      jsonDecode(jsonEncode(catalog.toJson())) as Map<String, dynamic>,
    );
    expect(restored, catalog);
    expect(restored.hashCode, catalog.hashCode);
    catalog = restored;
    expect(catalog.entries(BangumiMirrorType.image), isEmpty);
    expect(
      catalog.knownUrls(BangumiMirrorType.image),
      containsAll([old.url, next.url]),
    );
    BtrBangumiApi.setMirrorCatalog(catalog);
    BtrBangumiApi.setImageBaseUrl(BTAppConstants.anibtBangumiImageBaseUrl);
    expect(
      BtrBangumiApi.rewriteUrl('${old.url}/pic/cover.jpg?x=1#image'),
      '${BTAppConstants.anibtBangumiImageBaseUrl}/pic/cover.jpg?x=1#image',
    );
    expect(
      BtrBangumiApi.rewriteUrl('${next.url}/pic/cover.jpg'),
      '${BTAppConstants.anibtBangumiImageBaseUrl}/pic/cover.jpg',
    );
  });

  test(
    'custom selections preserve paths while choosing scheme and port per type',
    () {
      BtrBangumiApi.setBaseUrl('http://api.example.test:8081');
      BtrBangumiApi.setSiteBaseUrl('https://site.example.test:8443');
      BtrBangumiApi.setImageBaseUrl('http://image.example.test:8082');
      expect(
        BtrBangumiApi.rewriteUrl(
          'https://api.bgm.tv/v0/subjects/876?x=1#section',
        ),
        'http://api.example.test:8081/v0/subjects/876?x=1#section',
      );
      expect(
        BtrBangumiApi.rewriteUrl('https://bangumi.vip/subject/876'),
        'https://site.example.test:8443/subject/876',
      );
      expect(
        BtrBangumiApi.rewriteUrl('https://lain.bgm.tv/pic/test.jpg'),
        'http://image.example.test:8082/pic/test.jpg',
      );
      expect(BtrBangumiOauth.oauthBaseUrl, 'https://bgm.tv/oauth');
      expect(BtrBangumiOauth.oauthAuthorizeBaseUrl, 'https://bgm.tv/oauth');
      expect(
        BtrBangumiApi.nextBaseUrl,
        BTAppConstants.officialBangumiNextBaseUrl,
      );
    },
  );

  test('shared custom origins distinguish image and API resource paths', () {
    var mirror = BangumiMirror(
      name: '共用镜像',
      url: 'https://shared.example.test',
    );
    var catalog = const BangumiMirrorCatalog();
    for (var type in BangumiMirrorType.values) {
      catalog = catalog.save(type, mirror).remove(type, mirror.url);
    }
    BtrBangumiApi.setMirrorCatalog(catalog);
    BtrBangumiApi.setBaseUrl(BTAppConstants.officialBangumiApiBaseUrl);
    BtrBangumiApi.setSiteBaseUrl(BTAppConstants.bangumiVipSiteBaseUrl);
    BtrBangumiApi.setImageBaseUrl(BTAppConstants.anibtBangumiImageBaseUrl);
    expect(
      BtrBangumiApi.rewriteUrl('${mirror.url}/v0/subjects/876'),
      '${BTAppConstants.officialBangumiApiBaseUrl}/v0/subjects/876',
    );
    expect(
      BtrBangumiApi.rewriteUrl('${mirror.url}/subject/876'),
      '${BTAppConstants.bangumiVipSiteBaseUrl}/subject/876',
    );
    expect(
      BtrBangumiApi.rewriteUrl('${mirror.url}/r/200/pic/test.jpg'),
      '${BTAppConstants.anibtBangumiImageBaseUrl}/r/200/pic/test.jpg',
    );
    expect(
      BtrBangumiApi.rewriteUrl('https://external.example.test/pic/test.jpg'),
      'https://external.example.test/pic/test.jpg',
    );
  });
}
