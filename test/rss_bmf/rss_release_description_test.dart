// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;

// Project imports:
import 'package:bangumi_today/widgets/rss/rss_release_description.dart';

String _text(String source) =>
    html.parseFragment(rssDescriptionHtml(source, isMarkdown: true)!).text ??
    '';

void main() {
  test('AniBT 二次转义的 nbsp 解码为空白而不是文字', () {
    var text = _text('第一行\n&amp;nbsp;\n&amp;nbsp;\n第二行');
    expect(text, contains('\u00A0'));
    expect(text, isNot(contains('&nbsp;')));
    expect(text, isNot(contains('&amp;')));
  });

  test('HTML 块中的二次转义实体同样还原', () {
    var text = _text('<p>&amp;nbsp;</p>\n\n后文');
    expect(text, contains('\u00A0'));
    expect(text, isNot(contains('&nbsp;')));
  });

  test('可见的 &amp; 与 &lt; 还原为字符', () {
    expect(_text('A &amp; B'), contains('A & B'));
    expect(_text('5 &lt; 6'), contains('5 < 6'));
  });

  test('解码后的标签仍是文字，不会变成元素', () {
    var rendered = rssDescriptionHtml(
      '&amp;lt;b&amp;gt;不是粗体&amp;lt;/b&amp;gt;',
      isMarkdown: true,
    )!;
    var fragment = html.parseFragment(rendered);
    expect(fragment.querySelector('b'), isNull);
    expect(fragment.text, contains('<b>不是粗体</b>'));
  });

  test('代码块保留实体原文', () {
    var text = _text('```text\n&nbsp;\n```');
    expect(text, contains('&nbsp;'));
    expect(text, isNot(contains('\u00A0')));
  });
}
