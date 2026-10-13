// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/utils/bangumi_review_preview.dart';
import 'package:bangumi_today/widgets/bangumi/bt_comment_image.dart';

void main() {
  test('接口摘要直接补省略号，不按字数再次截断', () {
    var source = List.filled(150, '摘要🌸').join();
    var preview = BangumiReviewPreview.fromSummary(source);
    expect(preview.text, '$source…');
    expect(preview.imageUrls, isEmpty);
  });

  test('条目 362006 的女主发型摘要将图片与文字分开', () {
    const source =
        '[img]https://i.vgy.me/wAu4Nq.png[/img] '
        '[img]https://i.vgy.me/PKIlZZ.png[/img] 2015-08-19';
    var preview = BangumiReviewPreview.fromSummary(source);
    expect(preview.text, '2015-08-19…');
    expect(preview.imageUrls, [
      'https://i.vgy.me/wAu4Nq.png',
      'https://i.vgy.me/PKIlZZ.png',
    ]);
    expect(
      preview.imageUrls.map(resolveBangumiCommentImage),
      preview.imageUrls,
    );
  });

  test('样式、链接与引用保留文字并还原转义', () {
    var preview = BangumiReviewPreview.fromSummary(
      '[b]标题[/b] &quot;正文&quot;\n'
      '[quote]引用 [url=https://bgm.tv]链接[/url][/quote]后文',
    );
    expect(preview.text, '标题 "正文" 引用 链接 后文…');
    expect(preview.imageUrls, isEmpty);
  });

  test('图片在正文中间时保留前后文字及图片顺序', () {
    var preview = BangumiReviewPreview.fromSummary(
      '前文[img]https://example.com/a.png[/img]后文',
    );
    expect(preview.text, '前文 后文…');
    expect(preview.imageUrls, ['https://example.com/a.png']);
  });

  test('只有图片的摘要仍显示省略提示', () {
    var preview = BangumiReviewPreview.fromSummary(
      '[img]https://example.com/a.png[/img]',
    );
    expect(preview.text, '…');
    expect(preview.imageUrls, ['https://example.com/a.png']);
  });

  test('已有省略号时不重复追加', () {
    expect(BangumiReviewPreview.fromSummary('正文…').text, '正文…');
    expect(BangumiReviewPreview.fromSummary('正文...').text, '正文...');
  });

  test('空摘要不凭空显示省略号', () {
    expect(BangumiReviewPreview.fromSummary(' \r\n ').text, isEmpty);
    expect(BangumiReviewPreview.fromSummary('[b][/b]').text, isEmpty);
  });

  test('剧透与遮挡内容在摘要中保持隐藏，代码中的图片不渲染', () {
    var preview = BangumiReviewPreview.fromSummary(
      '[mask]答案[/mask][spoiler]剧透'
      '[img]https://example.com/spoiler.png[/img][/spoiler]'
      '[code][img]这是代码[/img][/code]',
    );
    expect(preview.text, '[隐藏内容] [剧透内容] [img]这是代码[/img]…');
    expect(preview.imageUrls, isEmpty);
  });
}
