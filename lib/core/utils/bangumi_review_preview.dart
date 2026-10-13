// Project imports:
import 'bangumi_comment_parser.dart';
import 'tool_func.dart';

/// 将接口已经截取的评论摘要转成列表文案与图片，不再按字数截断。
class BangumiReviewPreview {
  const BangumiReviewPreview({required this.text, required this.imageUrls});

  final String text;
  final List<String> imageUrls;

  factory BangumiReviewPreview.fromSummary(String summary) {
    var text = StringBuffer();
    var images = <String>[];

    void walk(List<BtCommentBlock> blocks) {
      for (var block in blocks) {
        switch (block) {
          case BtCommentParagraph(:var spans):
            for (var span in spans) {
              if (span.isImage) {
                if (span.imageKind == BtCommentImageKind.content) {
                  images.add(span.imageUrl!);
                  text.write(' ');
                } else {
                  text.write(' [表情] ');
                }
              } else {
                text.write(span.masked ? '[隐藏内容]' : span.text);
              }
            }
          case BtCommentQuote(:var blocks):
            walk(blocks);
          case BtCommentCode(text: var code):
            // 代码中的图片标签属于代码，不发起图片请求。
            text.write(code);
          case BtCommentSpoiler():
            text.write('[剧透内容]');
        }
        text.write(' ');
      }
    }

    walk(parseBangumiComment(replaceEscape(summary)));
    var preview = text.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (preview.isEmpty && images.isNotEmpty) {
      preview = '…';
    } else if (preview.isNotEmpty &&
        !RegExp(r'(?:…|\.{3})$').hasMatch(preview)) {
      preview = '$preview…';
    }
    return BangumiReviewPreview(
      text: preview,
      imageUrls: List.unmodifiable(images),
    );
  }
}
