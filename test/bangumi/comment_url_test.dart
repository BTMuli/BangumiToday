// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/constants/app_constants.dart';
import 'package:bangumi_today/core/utils/bangumi_comment_parser.dart';
import 'package:bangumi_today/request/bangumi/bangumi_api.dart';
import 'package:bangumi_today/widgets/bangumi/bt_comment_image.dart';
import 'package:bangumi_today/widgets/bangumi/comment_image_viewer.dart';

void main() {
  late String originalBaseUrl;

  setUp(() {
    originalBaseUrl = BtrBangumiApi.baseUrl;
    BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiProApiBaseUrl);
  });

  tearDown(() => BtrBangumiApi.setBaseUrl(originalBaseUrl));

  test('protocol-relative URLs retain their external host', () {
    expect(
      resolveBangumiCommentImage('//cdn.example.test/photo.png'),
      'https://cdn.example.test/photo.png',
    );
    expect(
      resolveBangumiCommentLink('//example.test/page'),
      'https://example.test/page',
    );
  });

  test('relative paths resolve against their corresponding mirror', () {
    expect(
      resolveBangumiCommentImage('/img/smiles/tv/15.gif'),
      '${BTAppConstants.bangumiProImageBaseUrl}/img/smiles/tv/15.gif',
    );
    expect(
      resolveBangumiCommentLink('/user/test'),
      '${BTAppConstants.bangumiProSiteBaseUrl}/user/test',
    );
  });

  test('official absolute and protocol-relative URLs follow the mirror', () {
    expect(
      resolveBangumiCommentImage('//lain.bgm.tv/pic/test.jpg'),
      '${BTAppConstants.bangumiProImageBaseUrl}/pic/test.jpg',
    );
    expect(
      resolveBangumiCommentLink('https://bgm.tv/ep/522'),
      '${BTAppConstants.bangumiProSiteBaseUrl}/ep/522',
    );
  });

  test('relative paths also resolve with the official API selected', () {
    BtrBangumiApi.setBaseUrl(BTAppConstants.officialBangumiApiBaseUrl);

    expect(
      resolveBangumiCommentImage('/img/smiles/tv/15.gif'),
      '${BTAppConstants.officialBangumiImageBaseUrl}/img/smiles/tv/15.gif',
    );
    expect(
      resolveBangumiCommentLink('/user/test'),
      '${BTAppConstants.officialBangumiSiteBaseUrl}/user/test',
    );
  });

  test('valid external HTTP and HTTPS URLs remain usable', () {
    for (var url in [
      'http://example.test/page?x=1&y=2#section',
      'https://example.test/photo.png',
    ]) {
      expect(resolveBangumiCommentLink(url), url);
      expect(resolveBangumiCommentImage(url), url);
    }
    expect(
      resolveBangumiCommentLink('  HTTPS://example.test/page  '),
      'https://example.test/page',
    );
  });

  test('local files, custom protocols and malformed URLs are rejected', () {
    for (var url in [
      'file:///C:/Windows/System32/calc.exe',
      'FILE:///C:/Windows/System32/calc.exe',
      'javascript:alert(1)',
      'data:text/html,example',
      'ms-settings:display',
      'bangumitoday://subject/8',
      'mailto:user@example.test',
      'ftp://example.test/photo.png',
      r'C:\Windows\System32\calc.exe',
      r'\\server\share\program.exe',
      'relative-file.exe',
      'https:',
      'https:///photo.png',
      'https://[invalid',
      '',
      '   ',
    ]) {
      expect(resolveBangumiCommentLink(url), isNull, reason: url);
      expect(resolveBangumiCommentImage(url), isNull, reason: url);
    }
  });

  test('BBCode links cannot select a local executable', () {
    var blocks = parseBangumiComment(
      '[url=file:///C:/Windows/System32/calc.exe]view image[/url]',
    );
    var span = (blocks.single as BtCommentParagraph).spans.single;

    expect(span.text, 'view image');
    expect(resolveBangumiCommentLink(span.link!), isNull);
  });

  test('invalid images do not shift gallery indexes across comments', () {
    var images = CommentImageSet();
    expect(
      images.add(
        '[img]file:///C:/Windows/System32/calc.exe[/img]'
        '[img]//cdn.example.test/first.png[/img]',
      ),
      0,
    );
    expect(images.length, 1);
    expect(images.add('[img]javascript:alert(1)[/img]'), 1);
    expect(images.length, 1);
    expect(images.add('[img]https://example.test/second.png[/img]'), 1);
    expect(images.length, 2);
  });
}
