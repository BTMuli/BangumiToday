/// bgm 评论（吐槽）正文解析：BBCode 子集 + bmoji 表情。
///
/// 只做结构化解析、不依赖 Flutter，渲染见 `BtCommentContent`。
/// 表情路径规则对齐 bgm.tv 的实际输出，例如：
/// - `(bgm38)`     → `/img/smiles/tv/15.gif`
/// - `(bgm509)`    → `/img/smiles/tv_500/bgm_509.png`
/// - `(musume_07)` → `/img/smiles/musume/musume_07.gif`
library;

/// 行内图片片段的来源，渲染尺寸与插值方式不同。
enum BtCommentImageKind {
  /// 旧版像素风表情，需要关闭插值
  legacySmile,

  /// 动态表情，尺寸较大
  dynamicSmile,

  /// `[img]` 标签里的图片
  content,
}

/// 行内片段：文本、表情或图片。
class BtCommentSpan {
  const BtCommentSpan({
    this.text = '',
    this.imageUrl,
    this.imageKind,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.color,
    this.size,
    this.link,
    this.masked = false,
  });

  /// 文本内容
  final String text;

  /// 表情或图片地址；非空时忽略 [text]
  final String? imageUrl;

  /// 图片来源
  final BtCommentImageKind? imageKind;

  /// 粗体
  final bool bold;

  /// 斜体
  final bool italic;

  /// 下划线
  final bool underline;

  /// 删除线
  final bool strike;

  /// `[color=..]` 的原始值，由渲染层解析
  final String? color;

  /// `[size=..]` 的字号，单位 px
  final double? size;

  /// 链接地址：绝对 URL，或以 `/` 开头的站点相对路径
  final String? link;

  /// `[mask]` 隐藏文本，需要交互后才显示
  final bool masked;

  /// 是否为图片片段
  bool get isImage => imageUrl != null;
}

/// 块级节点
sealed class BtCommentBlock {
  const BtCommentBlock();
}

/// 普通段落，换行即分段
class BtCommentParagraph extends BtCommentBlock {
  const BtCommentParagraph(this.spans);

  final List<BtCommentSpan> spans;
}

/// 引用块
class BtCommentQuote extends BtCommentBlock {
  const BtCommentQuote({required this.blocks, this.title});

  final List<BtCommentBlock> blocks;
  final String? title;
}

/// 代码块，内容不做行内解析
class BtCommentCode extends BtCommentBlock {
  const BtCommentCode(this.text);

  final String text;
}

/// 剧透块，默认折叠
class BtCommentSpoiler extends BtCommentBlock {
  const BtCommentSpoiler({required this.blocks, this.title});

  final List<BtCommentBlock> blocks;
  final String? title;
}

/// 表情解析结果
class BtBangumiSmile {
  const BtBangumiSmile(this.path, this.kind);

  /// 相对图片域名的路径
  final String path;
  final BtCommentImageKind kind;
}

/// 已知的动态表情组；bgm 新增表情组时在此追加。
const Set<String> bangumiDynamicSmileSets = {'musume', 'blake'};

/// `tv_500` 组里使用 gif 的代码，其余为 png。
const Set<int> _tv500GifCodes = {
  500,
  501,
  505,
  515,
  516,
  517,
  518,
  519,
  521,
  522,
  523,
};

const Set<int> _tv500PngCodes = {
  502,
  503,
  504,
  506,
  507,
  508,
  509,
  510,
  511,
  512,
  513,
  514,
  520,
  524,
  525,
  526,
  527,
  528,
  529,
};

/// 链接尾部需要剔除的标点
const String _urlTailPunctuation = '.,;:!?、。，；：！？）]】」》”\'"';

/// 解析表情代码，无法识别时返回 null（按普通文本渲染）。
BtBangumiSmile? resolveBangumiSmile(String code) {
  var legacy = RegExp(r'^bgm(\d+)$').firstMatch(code);
  if (legacy != null) {
    var number = int.tryParse(legacy.group(1)!);
    if (number == null) return null;
    var path = _legacySmilePath(number);
    if (path == null) return null;
    return BtBangumiSmile(path, BtCommentImageKind.legacySmile);
  }
  var dynamic = RegExp(r'^([a-z][a-z0-9]*)_[a-z0-9]+$').firstMatch(code);
  if (dynamic == null) return null;
  var set = dynamic.group(1)!;
  if (!bangumiDynamicSmileSets.contains(set)) return null;
  return BtBangumiSmile(
    '/img/smiles/$set/$code.gif',
    BtCommentImageKind.dynamicSmile,
  );
}

/// `(bgmNN)` 的图片路径：本站旧表情分三组存放，序号与文件名并不一致。
String? _legacySmilePath(int code) {
  if (code >= 1 && code <= 9) return '/img/smiles/bgm/0$code.png';
  if (code == 10) return '/img/smiles/bgm/10.png';
  if (code == 11) return '/img/smiles/bgm/11.gif';
  if (code >= 12 && code <= 22) return '/img/smiles/bgm/$code.png';
  if (code == 23) return '/img/smiles/bgm/23.gif';
  // tv 组：文件序号从 1 开始，与代码相差 23，1..9 补零。
  if (code >= 24 && code <= 125) {
    var file = (code - 23).toString().padLeft(2, '0');
    return '/img/smiles/tv/$file.gif';
  }
  if (code >= 200 && code <= 238) return '/img/smiles/tv_vs/bgm_$code.png';
  if (_tv500GifCodes.contains(code)) {
    return '/img/smiles/tv_500/bgm_$code.gif';
  }
  if (_tv500PngCodes.contains(code)) {
    return '/img/smiles/tv_500/bgm_$code.png';
  }
  return null;
}

/// 解析评论正文
List<BtCommentBlock> parseBangumiComment(String source) {
  return _CommentParser(source).parseBlocks(const {});
}

/// 按渲染顺序取出正文里的图片地址。
///
/// [kind] 为空时同时包含表情与 `[img]`，指定后只取该类图片。
/// 顺序与 `BtCommentContent` 的渲染顺序一致，供图片弹窗左右切换使用；
/// `[code]` 内容不参与渲染，其中的图片因此不会出现在结果里。
List<String> bangumiCommentImageUrls(
  String source, {
  BtCommentImageKind? kind,
}) {
  var urls = <String>[];

  void walk(List<BtCommentBlock> blocks) {
    for (var block in blocks) {
      switch (block) {
        case BtCommentParagraph(:var spans):
          for (var span in spans) {
            if (!span.isImage) continue;
            if (kind != null && span.imageKind != kind) continue;
            urls.add(span.imageUrl!);
          }
        case BtCommentQuote(:var blocks):
          walk(blocks);
        case BtCommentSpoiler(:var blocks):
          walk(blocks);
        case BtCommentCode():
          break;
      }
    }
  }

  walk(parseBangumiComment(source));
  return urls;
}

/// 行内样式标签，闭合时会恢复上一层样式
const Set<String> _styleTags = {
  'b',
  'i',
  'u',
  's',
  'color',
  'size',
  'url',
  'user',
};

/// 当前生效的行内样式
class _CommentStyle {
  bool bold = false;
  bool italic = false;
  bool underline = false;
  bool strike = false;
  String? color;
  double? size;
  String? link;

  _CommentStyle copy() => _CommentStyle()
    ..bold = bold
    ..italic = italic
    ..underline = underline
    ..strike = strike
    ..color = color
    ..size = size
    ..link = link;

  BtCommentSpan span(String text, {String? link, bool masked = false}) =>
      BtCommentSpan(
        text: text,
        bold: bold,
        italic: italic,
        underline: underline,
        strike: strike,
        color: color,
        size: size,
        link: link ?? this.link,
        masked: masked,
      );
}

class _OpenTag {
  const _OpenTag(this.name, this.style);

  final String name;

  /// 进入该标签前的样式快照
  final _CommentStyle style;
}

class _Tag {
  const _Tag({
    required this.name,
    required this.closing,
    required this.raw,
    this.value,
  });

  final String name;
  final bool closing;
  final String raw;
  final String? value;
}

class _CommentParser {
  _CommentParser(this.source);

  final String source;
  int _index = 0;

  static final RegExp _nameRegExp = RegExp(r'^[a-zA-Z][a-zA-Z0-9]*$');
  // matchAsPrefix 已限定起点，模式里不能再加 `^`，否则只有字符串开头能匹配
  static final RegExp _smileRegExp = RegExp(r'\(([A-Za-z][A-Za-z0-9_]*)\)');
  static final RegExp _urlRegExp = RegExp(r'https?://[^\s<>"\]]+');
  static const List<String> _specialMarkers = [
    '[',
    '\n',
    '\r',
    '(',
    'http://',
    'https://',
  ];

  /// 解析到 [stop] 中的闭合标签或文本结尾
  List<BtCommentBlock> parseBlocks(Set<String> stop) {
    var blocks = <BtCommentBlock>[];
    var spans = <BtCommentSpan>[];
    var stack = <_OpenTag>[];
    var style = _CommentStyle();

    void flush() {
      if (spans.isEmpty) return;
      blocks.add(BtCommentParagraph(List<BtCommentSpan>.unmodifiable(spans)));
      spans = <BtCommentSpan>[];
    }

    while (_index < source.length) {
      var char = source[_index];
      if (char == '\r') {
        _index++;
        continue;
      }
      if (char == '\n') {
        _index++;
        flush();
        continue;
      }
      if (char == '[') {
        var tag = _readTag();
        if (tag == null) {
          spans.add(style.span('['));
          _index++;
          continue;
        }
        if (tag.closing) {
          if (stop.contains(tag.name)) {
            flush();
            return blocks;
          }
          var open = stack.lastIndexWhere((item) => item.name == tag.name);
          if (open == -1) {
            // 没有配对的闭合标签按普通文本保留
            spans.add(style.span(tag.raw));
            continue;
          }
          style = stack[open].style.copy();
          stack.removeRange(open, stack.length);
          continue;
        }
        if (tag.name == 'quote') {
          flush();
          blocks.add(
            BtCommentQuote(
              title: _tagValue(tag),
              blocks: parseBlocks(const {'quote'}),
            ),
          );
          continue;
        }
        if (tag.name == 'spoiler') {
          flush();
          blocks.add(
            BtCommentSpoiler(
              title: _tagValue(tag),
              blocks: parseBlocks(const {'spoiler'}),
            ),
          );
          continue;
        }
        if (tag.name == 'code') {
          flush();
          blocks.add(BtCommentCode(_readRawUntil('code')));
          continue;
        }
        if (tag.name == 'img') {
          var url = _readRawUntil('img').trim();
          if (url.isNotEmpty) {
            spans.add(
              BtCommentSpan(
                imageUrl: url,
                imageKind: BtCommentImageKind.content,
              ),
            );
          }
          continue;
        }
        if (tag.name == 'mask') {
          spans.add(style.span(_readRawUntil('mask'), masked: true));
          continue;
        }
        if (tag.name == 'url' && _tagValue(tag) == null) {
          var text = _readRawUntil('url').trim();
          spans.add(
            style.span(text, link: text.startsWith('http') ? text : null),
          );
          continue;
        }
        if (_styleTags.contains(tag.name)) {
          stack.add(_OpenTag(tag.name, style.copy()));
          _applyStyle(style, tag);
          continue;
        }
        // 内容保留、样式忽略的标签同样入栈，避免闭合标签残留成文本
        stack.add(_OpenTag(tag.name, style.copy()));
        continue;
      }
      if (char == '(') {
        var match = _smileRegExp.matchAsPrefix(source, _index);
        var smile = match == null ? null : resolveBangumiSmile(match.group(1)!);
        if (match != null && smile != null) {
          spans.add(BtCommentSpan(imageUrl: smile.path, imageKind: smile.kind));
          _index += match.end - match.start;
          continue;
        }
      }
      if (char == 'h') {
        var match = _urlRegExp.matchAsPrefix(source, _index);
        if (match != null) {
          var url = _trimUrlTail(match.group(0)!);
          spans.add(style.span(url, link: url));
          _index += url.length;
          continue;
        }
      }
      var next = _nextSpecialIndex();
      if (next <= _index) next = _index + 1;
      spans.add(style.span(source.substring(_index, next)));
      _index = next;
    }
    flush();
    return blocks;
  }

  String? _tagValue(_Tag tag) {
    var value = tag.value?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  void _applyStyle(_CommentStyle style, _Tag tag) {
    switch (tag.name) {
      case 'b':
        style.bold = true;
      case 'i':
        style.italic = true;
      case 'u':
        style.underline = true;
      case 's':
        style.strike = true;
      case 'color':
        var value = _tagValue(tag);
        if (value != null) style.color = value;
      case 'size':
        var value = double.tryParse(_tagValue(tag) ?? '');
        if (value != null) style.size = value.clamp(10, 36).toDouble();
      case 'url':
      case 'user':
        var value = _tagValue(tag);
        if (value == null) return;
        style.link = tag.name == 'user' ? '/user/$value' : value;
    }
  }

  /// 下一个需要特殊处理的位置：[ 换行 ( 或链接开头
  int _nextSpecialIndex() {
    var best = source.length;
    for (var marker in _specialMarkers) {
      var at = source.indexOf(marker, _index);
      if (at != -1 && at < best) best = at;
    }
    return best;
  }

  /// 读取标签；当前位置不是合法标签时返回 null
  _Tag? _readTag() {
    var end = source.indexOf(']', _index);
    if (end == -1) return null;
    var raw = source.substring(_index, end + 1);
    if (raw.length > 64 || raw.contains('\n')) return null;
    var body = source.substring(_index + 1, end).trim();
    if (body.isEmpty) return null;
    if (body.startsWith('/')) {
      var name = body.substring(1).trim();
      if (!_nameRegExp.hasMatch(name)) return null;
      _index = end + 1;
      return _Tag(name: name.toLowerCase(), closing: true, raw: raw);
    }
    var separator = body.indexOf('=');
    var name = separator == -1 ? body : body.substring(0, separator);
    var value = separator == -1 ? null : body.substring(separator + 1).trim();
    if (!_nameRegExp.hasMatch(name)) return null;
    _index = end + 1;
    return _Tag(
      name: name.toLowerCase(),
      closing: false,
      raw: raw,
      value: value,
    );
  }

  /// 读取到 `[/name]` 为止的原始文本，不做行内解析
  String _readRawUntil(String name) {
    var closing = RegExp('\\[/$name\\]', caseSensitive: false);
    var match = closing.firstMatch(source.substring(_index));
    if (match == null) {
      var rest = source.substring(_index);
      _index = source.length;
      return rest;
    }
    var content = source.substring(_index, _index + match.start);
    _index += match.end;
    return content;
  }

  /// 去掉链接尾部的标点，避免把中文句读吞进链接
  String _trimUrlTail(String url) {
    var result = url;
    while (result.isNotEmpty &&
        _urlTailPunctuation.contains(result[result.length - 1])) {
      result = result.substring(0, result.length - 1);
    }
    return result.isEmpty ? url : result;
  }
}
