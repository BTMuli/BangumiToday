// 评论正文解析的功能回归测试：表情映射与 BBCode 子集。

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/utils/bangumi_comment_parser.dart';

/// 所有段落的行内片段
List<BtCommentSpan> _spans(String source) => [
  for (var block in parseBangumiComment(source))
    if (block is BtCommentParagraph) ...block.spans,
];

/// 去掉标签后的纯文本
String _text(String source) => _spans(source).map((span) => span.text).join();

void main() {
  group('bmoji 表情', () {
    test('旧版表情按 bgm 的文件规则映射', () {
      expect(_spans('(bgm38)').single.imageUrl, '/img/smiles/tv/15.gif');
      expect(_spans('(bgm01)').single.imageUrl, '/img/smiles/bgm/01.png');
      expect(_spans('(bgm10)').single.imageUrl, '/img/smiles/bgm/10.png');
      expect(_spans('(bgm11)').single.imageUrl, '/img/smiles/bgm/11.gif');
      expect(_spans('(bgm16)').single.imageUrl, '/img/smiles/bgm/16.png');
      expect(_spans('(bgm23)').single.imageUrl, '/img/smiles/bgm/23.gif');
      expect(_spans('(bgm24)').single.imageUrl, '/img/smiles/tv/01.gif');
      expect(_spans('(bgm30)').single.imageUrl, '/img/smiles/tv/07.gif');
      expect(_spans('(bgm99)').single.imageUrl, '/img/smiles/tv/76.gif');
      expect(_spans('(bgm125)').single.imageUrl, '/img/smiles/tv/102.gif');
      expect(
        _spans('(bgm200)').single.imageUrl,
        '/img/smiles/tv_vs/bgm_200.png',
      );
      expect(
        _spans('(bgm238)').single.imageUrl,
        '/img/smiles/tv_vs/bgm_238.png',
      );
      expect(
        _spans('(bgm505)').single.imageUrl,
        '/img/smiles/tv_500/bgm_505.gif',
      );
      expect(
        _spans('(bgm509)').single.imageUrl,
        '/img/smiles/tv_500/bgm_509.png',
      );
      expect(
        _spans('(bgm524)').single.imageUrl,
        '/img/smiles/tv_500/bgm_524.png',
      );
      expect(
        _spans('(bgm38)').single.imageKind,
        BtCommentImageKind.legacySmile,
      );
    });

    test('动态表情与未收录代码', () {
      var musume = _spans('(musume_07)').single;
      expect(musume.imageUrl, '/img/smiles/musume/musume_07.gif');
      expect(musume.imageKind, BtCommentImageKind.dynamicSmile);
      expect(
        _spans('(blake_01)').single.imageUrl,
        '/img/smiles/blake/blake_01.gif',
      );
      // 未收录的表情组与越界代码按普通文本保留
      expect(_text('(bgm999)'), '(bgm999)');
      expect(_text('(tokei_01)'), '(tokei_01)');
      expect(_text('（bgm38）'), '（bgm38）');
      expect(_text('(bgm38'), '(bgm38');
    });

    test('真实吐槽正文按行分段', () {
      var source =
          '火浣布做衣服应该不会很漂亮，而且石棉也有害(bgm38)\r\n'
          '不过作者是真有东西，博物志怪资料没少查(musume_07)。';
      var blocks = parseBangumiComment(source);
      expect(blocks.length, 2);
      var images = [
        for (var span in _spans(source))
          if (span.isImage) span.imageUrl,
      ];
      expect(images, [
        '/img/smiles/tv/15.gif',
        '/img/smiles/musume/musume_07.gif',
      ]);
      expect(_text(source), contains('火浣布做衣服应该不会很漂亮'));
    });
  });

  group('行内样式与链接', () {
    test('样式标签', () {
      var bold = _spans('[b]粗体[/b]').single;
      expect(bold.text, '粗体');
      expect(bold.bold, isTrue);
      var mixed = _spans('[u][s]划掉[/s][/u]').single;
      expect(mixed.underline, isTrue);
      expect(mixed.strike, isTrue);
      var colored = _spans('[color=#ff0000]红[/color]').single;
      expect(colored.color, '#ff0000');
      var sized = _spans('[size=24]大[/size]').single;
      expect(sized.size, 24);
    });

    test('闭合标签后恢复外层样式', () {
      var outer = _spans('[b]粗[color=red]红[/color]还是粗[/b]');
      expect(outer.length, 3);
      expect(outer[0].bold, isTrue);
      expect(outer[1].color, 'red');
      expect(outer[1].bold, isTrue);
      expect(outer[2].bold, isTrue);
      expect(outer[2].color, isNull);
    });

    test('链接', () {
      var named = _spans('[url=https://bgm.tv/ep/1]章节[/url]').single;
      expect(named.text, '章节');
      expect(named.link, 'https://bgm.tv/ep/1');
      var bare = _spans('[url]https://bgm.tv/ep/1[/url]').single;
      expect(bare.link, 'https://bgm.tv/ep/1');
      var plain = _spans('见 https://bgm.tv/ep/1。');
      expect(plain.first.text, '见 ');
      expect(plain.last.text, '。');
      var link = plain.firstWhere((span) => span.link != null);
      expect(link.text, 'https://bgm.tv/ep/1');
      expect(link.link, 'https://bgm.tv/ep/1');
    });

    test('[img] 与 [mask]', () {
      var image = _spans('[img]//lain.bgm.tv/pic/1.jpg[/img]').single;
      expect(image.isImage, isTrue);
      expect(image.imageUrl, '//lain.bgm.tv/pic/1.jpg');
      expect(image.imageKind, BtCommentImageKind.content);
      var masked = _spans('答案[mask]是 42[/mask]').last;
      expect(masked.text, '是 42');
      expect(masked.masked, isTrue);
    });
  });

  group('块级标签', () {
    test('引用与换行', () {
      var blocks = parseBangumiComment('[quote]引用内容[/quote]\n正文');
      expect(blocks.length, 2);
      expect(blocks.first, isA<BtCommentQuote>());
      var quote = blocks.first as BtCommentQuote;
      expect(quote.blocks.length, 1);
      expect(blocks.last, isA<BtCommentParagraph>());
    });

    test('代码块不做行内解析', () {
      var blocks = parseBangumiComment('[code][b](bgm38)[/b][/code]');
      expect(blocks.single, isA<BtCommentCode>());
      var code = blocks.single as BtCommentCode;
      expect(code.text, '[b](bgm38)[/b]');
    });

    test('剧透块', () {
      var blocks = parseBangumiComment('[spoiler=结局]结局内容[/spoiler]');
      expect(blocks.single, isA<BtCommentSpoiler>());
      var spoiler = blocks.single as BtCommentSpoiler;
      expect(spoiler.title, '结局');
      expect(spoiler.blocks.length, 1);
    });

    test('未知标签保留内容', () {
      expect(_text('[font=微软雅黑]内容[/font]'), '内容');
      expect(_text('[align=center]居中[/align]'), '居中');
      expect(_text('普通 [方括号] 文本'), '普通 [方括号] 文本');
    });

    test('未配对的闭合标签按文本保留', () {
      expect(_text('前[/b]后'), '前[/b]后');
    });

    test('空正文与纯换行', () {
      expect(parseBangumiComment(''), isEmpty);
      expect(parseBangumiComment('\r\n\r\n'), isEmpty);
    });
  });

  group('图片顺序', () {
    test('按渲染顺序收集表情与 [img]，跳过代码块', () {
      var source =
          '开头(bgm38)[img]https://a.com/1.png[/img]\n'
          '引用[quote](musume_07)[/quote]'
          '剧透[spoiler](bgm39)[/spoiler]'
          '代码[code](bgm40)[/code](bgm41)';
      expect(bangumiCommentImageUrls(source), [
        '/img/smiles/tv/15.gif',
        'https://a.com/1.png',
        '/img/smiles/musume/musume_07.gif',
        '/img/smiles/tv/16.gif',
        '/img/smiles/tv/18.gif',
      ]);
    });

    test('无图正文返回空列表', () {
      expect(bangumiCommentImageUrls('普通文本 [b]粗体[/b]'), isEmpty);
      expect(bangumiCommentImageUrls(''), isEmpty);
    });

    test('按类型过滤：弹窗只取 [img] 内容图片', () {
      var source = '(bgm38)[img]https://a.com/1.png[/img](musume_07)';
      expect(
        bangumiCommentImageUrls(source, kind: BtCommentImageKind.content),
        ['https://a.com/1.png'],
      );
      expect(
        bangumiCommentImageUrls(source, kind: BtCommentImageKind.legacySmile),
        ['/img/smiles/tv/15.gif'],
      );
    });
  });
}
