// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:html_unescape/html_unescape.dart';
import 'package:markdown/markdown.dart' as md;

/// AniBT 的描述保留 Markdown；其他 RSS 的 HTML 原样交给富文本组件。
String? rssDescriptionHtml(String? description, {bool isMarkdown = false}) {
  var text = description;
  if (text == null || text.trim().isEmpty) return null;
  if (!isMarkdown) return text.trim();
  var htmlBlocks = <String>[];
  var rendered = md.markdownToHtml(
    _separateHtmlBlocks(text, htmlBlocks),
    extensionSet: md.ExtensionSet.gitHubFlavored,
  );
  for (var index = 0; index < htmlBlocks.length; index++) {
    rendered = rendered.replaceAll(
      '<div data-bt-rss-block="$index"></div>',
      htmlBlocks[index],
    );
  }
  return rendered;
}

/// RSS 会在 Markdown 前后插入 HTML 摘要、图片和换行标签。
/// 分开完整 HTML 行，避免它们将后续 Markdown 吞入原始 HTML 块。
String _separateHtmlBlocks(String text, List<String> htmlBlocks) {
  var output = <String>[];
  void preserveHtml(String source) {
    var index = htmlBlocks.length;
    htmlBlocks.add(_renderHtmlBlock(source));
    output.addAll(['', '<div data-bt-rss-block="$index"></div>', '']);
  }

  String? fenceCharacter;
  var fenceLength = 0;
  var inPre = false;
  var fenceStart = RegExp(r'^ {0,3}(`{3,}|~{3,})');
  var fenceEnd = RegExp(r'^ {0,3}(`{3,}|~{3,})[ \t]*$');
  var preStart = RegExp(r'^ {0,3}<pre\b', caseSensitive: false);
  var preEnd = RegExp(r'</pre\s*>', caseSensitive: false);
  // AniBT 会将部分 *** 分隔符转换为 <em> </em> *，恢复其段落分隔语义。
  var partialThematicBreak = RegExp(
    r'^<em>[ \t]*</em>[ \t]*\*$',
    caseSensitive: false,
  );
  var boundary = RegExp(
    r'^(?:<(?:br|hr|img)\b[^>]*>|'
    r'</(?:p|div|ul|ol|blockquote|table|h[1-6])>)$',
    caseSensitive: false,
  );
  var lines = text.replaceAll('\r\n', '\n').split('\n');
  var htmlStart = RegExp(
    r'^<(p|div|details|ul|ol|table)\b',
    caseSensitive: false,
  );
  var escapedDetails = RegExp(
    r'^&lt;details(?:\s[^&]*)?&gt;',
    caseSensitive: false,
  );
  for (var index = 0; index < lines.length; index++) {
    var line = lines[index];
    if (fenceCharacter != null) {
      output.add(line);
      var closing = fenceEnd.firstMatch(line)?.group(1);
      if (closing != null &&
          closing[0] == fenceCharacter &&
          closing.length >= fenceLength) {
        fenceCharacter = null;
      }
      continue;
    }
    if (inPre || preStart.hasMatch(line)) {
      output.add(line);
      inPre = !preEnd.hasMatch(line);
      if (!inPre) output.add('');
      continue;
    }
    var fence = fenceStart.firstMatch(line)?.group(1);
    if (fence != null) {
      fenceCharacter = fence[0];
      fenceLength = fence.length;
      output.add(line);
      continue;
    }
    if (line.startsWith('    ') || line.startsWith('\t')) {
      output.add(line);
      continue;
    }
    if (partialThematicBreak.hasMatch(line.trim())) {
      output.addAll(['', '***', '']);
      continue;
    }
    if (escapedDetails.hasMatch(line.trimLeft())) {
      var end = index;
      while (end < lines.length && !lines[end].contains('&lt;/details&gt;')) {
        end++;
      }
      if (end < lines.length) {
        var decoded = HtmlUnescape().convert(
          lines.sublist(index, end + 1).join('\n'),
        );
        // 先保护代码中的字面标签，不能将其当作 HTML 元素解析。
        decoded = decoded.replaceAllMapped(
          RegExp(r'<pre\b[^>]*>([\s\S]*?)</pre>', caseSensitive: false),
          (match) {
            var code = match[1]!
                .replaceFirst(
                  RegExp(r'^<code\b[^>]*>', caseSensitive: false),
                  '',
                )
                .replaceFirst(RegExp(r'</code>\s*$', caseSensitive: false), '')
                .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
            return '<pre><code>${const HtmlEscape().convert(code)}</code></pre>';
          },
        );
        preserveHtml(decoded);
        index = end;
        continue;
      }
    }
    var start = htmlStart.firstMatch(line.trimLeft());
    if (start != null) {
      var tag = start[1]!;
      var tags = RegExp('</?$tag\\b[^>]*>', caseSensitive: false);
      var depth = 0;
      var end = index;
      for (; end < lines.length; end++) {
        for (var match in tags.allMatches(lines[end])) {
          depth += match[0]!.startsWith('</') ? -1 : 1;
        }
        if (depth <= 0) break;
      }
      if (end < lines.length) {
        preserveHtml(lines.sublist(index, end + 1).join('\n'));
        index = end;
        continue;
      }
    }
    if (boundary.hasMatch(line.trim())) {
      output.addAll(['', line, '']);
    } else {
      output.add(line);
    }
  }
  return output.join('\n');
}

/// 原始 HTML 块不会经过 Markdown 的行内解析，单独处理其文字节点。
/// pre / code 保留原文，避免加粗标记或标签改变代码内容。
String _renderHtmlBlock(String source) {
  var fragment = html.parseFragment(source);
  void visit(dom.Node node) {
    if (node is dom.Element) {
      if (node.localName == 'pre') {
        var code = dom.Element.tag('code')..text = rssPreformattedText(node);
        node.nodes
          ..clear()
          ..add(code);
        return;
      }
      if (['code', 'kbd', 'samp'].contains(node.localName)) return;
    }
    if (node is dom.Text) {
      var text = node.data;
      if (!RegExp(r'\*\*|__|~~|```|~~~').hasMatch(text)) return;
      var parent = node.parentNode!;
      var inline =
          parent is dom.Element &&
          !['div', 'details'].contains(parent.localName);
      var replacement = html.parseFragment(
        md.markdownToHtml(
          text,
          inlineOnly: inline,
          extensionSet: md.ExtensionSet.gitHubFlavored,
        ),
      );
      for (var child in replacement.nodes.toList()) {
        parent.insertBefore(child, node);
      }
      node.remove();
      return;
    }
    for (var child in node.nodes.toList()) {
      visit(child);
    }
  }

  visit(fragment);
  return fragment.outerHtml;
}

/// 保留代码换行；HTML 的 br 也按换行处理，其他标签只读取文字内容。
String rssPreformattedText(dom.Node node) =>
    node is dom.Element && node.localName == 'br'
    ? '\n'
    : node is dom.Text
    ? node.data
    : node.nodes.map(rssPreformattedText).join();
