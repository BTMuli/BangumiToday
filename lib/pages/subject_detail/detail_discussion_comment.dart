// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../widgets/bangumi/bt_comment_content.dart';
import '../../widgets/bangumi/comment_image_viewer.dart';
import 'detail_comment_author.dart';
import 'subject_detail_colors.dart';

/// 章节与评论日志共用的吐槽卡片，正文、回复和图片沿用相同布局。
class DetailDiscussionComment extends StatefulWidget {
  const DetailDiscussionComment(
    this.comment, {
    super.key,
    required this.pageUrl,
    required this.floor,
  });

  final BangumiEpisodeComment comment;
  final String pageUrl;
  final int floor;

  @override
  State<DetailDiscussionComment> createState() =>
      _DetailDiscussionCommentState();
}

class _DetailDiscussionCommentState extends State<DetailDiscussionComment> {
  var _hovered = false;

  /// 本条吐槽（含回复）的图片集合，列表复用 State 时按评论实例重算
  BangumiEpisodeComment? _cachedComment;
  late CommentImageSet _images;
  late List<int> _textImageBase;

  void _syncImages() {
    var comment = widget.comment;
    if (identical(_cachedComment, comment)) return;
    _cachedComment = comment;
    var images = CommentImageSet();
    var bases = <int>[images.add(comment.content)];
    for (var reply in comment.replies) {
      bases.add(images.add(reply.content));
    }
    _images = images;
    _textImageBase = bases;
  }

  @override
  Widget build(BuildContext context) {
    var comment = widget.comment;
    var accent = FluentTheme.of(context).accentColor;
    var content = comment.content.trim();
    _syncImages();
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: BTTheme.animationDurationFast,
        curve: BTTheme.animationCurve,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SubjectDetailColors.card(context),
          borderRadius: BTRadius.mediumBR,
          border: Border.all(
            color: _hovered
                ? accent.withValues(alpha: 0.45)
                : BTColors.divider(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommentHeader(
              user: comment.user,
              createdAt: comment.createdAt,
              floor: '#${widget.floor}',
              commentUrl: '${widget.pageUrl}#post_${comment.id}',
            ),
            const SizedBox(height: 8),
            if (content.isEmpty)
              Text('未填写吐槽内容', style: BTTypography.caption(context))
            else
              BtCommentContent(
                text: content,
                imageIndexBase: _textImageBase.first,
                onImageTap: (index) => unawaited(_images.show(context, index)),
              ),
            if (comment.replies.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (var index = 0; index < comment.replies.length; index++)
                _ReplyBlock(
                  reply: comment.replies[index],
                  floor: '#${widget.floor}-${index + 1}',
                  commentUrl:
                      '${widget.pageUrl}#post_${comment.replies[index].id}',
                  imageIndexBase: _textImageBase[index + 1],
                  onImageTap: (image) =>
                      unawaited(_images.show(context, image)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 吐槽的回复块：缩进 + 次级底色，和顶层吐槽区分。
class _ReplyBlock extends StatelessWidget {
  const _ReplyBlock({
    required this.reply,
    required this.floor,
    required this.commentUrl,
    required this.imageIndexBase,
    required this.onImageTap,
  });

  final BangumiEpisodeCommentReply reply;
  final String floor;
  final String commentUrl;

  /// 本段正文的图片在整条吐槽里的起始下标
  final int imageIndexBase;
  final ValueChanged<int> onImageTap;

  @override
  Widget build(BuildContext context) {
    var content = reply.content.trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentHeader(
            user: reply.user,
            createdAt: reply.createdAt,
            floor: floor,
            commentUrl: commentUrl,
            avatarSize: 24,
          ),
          const SizedBox(height: 6),
          if (content.isEmpty)
            Text('未填写回复内容', style: BTTypography.caption(context))
          else
            BtCommentContent(
              text: content,
              imageIndexBase: imageIndexBase,
              onImageTap: onImageTap,
            ),
        ],
      ),
    );
  }
}

/// 吐槽标题行：头像、两行用户信息、发布时间与楼层定位链接。
class _CommentHeader extends StatelessWidget {
  const _CommentHeader({
    required this.user,
    required this.createdAt,
    required this.floor,
    required this.commentUrl,
    this.avatarSize = 36,
  });

  final BangumiCommentUser? user;

  /// 发布时间，Unix 秒
  final int createdAt;
  final String floor;
  final String commentUrl;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    var time = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000).toLocal();
    var floorLabel = '在浏览器中定位到 $floor 楼评论';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DetailCommentAuthor(user: user, avatarSize: avatarSize),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat('yyyy-MM-dd HH:mm').format(time),
              style: BTTypography.caption(context),
            ),
            const SizedBox(height: 2),
            Tooltip(
              message: floorLabel,
              child: Semantics(
                label: floorLabel,
                link: true,
                child: HyperlinkButton(
                  style: const ButtonStyle(
                    padding: WidgetStatePropertyAll(EdgeInsets.zero),
                    backgroundColor: WidgetStatePropertyAll(Colors.transparent),
                    textStyle: WidgetStatePropertyAll(
                      TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  onPressed: () => unawaited(launchUrlString(commentUrl)),
                  child: Text(floor),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
