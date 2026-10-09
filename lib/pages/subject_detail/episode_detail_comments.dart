// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../core/utils/tool_func.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../providers/app_providers.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import '../../widgets/bangumi/bt_comment_content.dart';
import '../../widgets/bangumi/comment_image_viewer.dart';
import 'subject_detail_colors.dart';
import 'subject_detail_module_status.dart';

/// 剧集评论页签。
///
/// 章节吐槽接口一次返回全部顶层吐槽及其回复，
/// 因此这里没有条目吐槽箱的筛选与分页，只保留刷新。
class EpisodeDetailComments extends ConsumerStatefulWidget {
  const EpisodeDetailComments({
    super.key,
    required this.episodeId,
    required this.total,
    required this.reloadToken,
  });

  final int episodeId;

  /// 章节详情给出的吐槽数，包含回复
  final int total;

  /// 父页面刷新计数，变化时重新拉取
  final int reloadToken;

  @override
  ConsumerState<EpisodeDetailComments> createState() =>
      _EpisodeDetailCommentsState();
}

class _EpisodeDetailCommentsState extends ConsumerState<EpisodeDetailComments> {
  List<BangumiEpisodeComment> _comments = [];
  bool _loading = true;
  String? _error;
  int _generation = 0;

  int get _replyCount =>
      _comments.fold(0, (sum, comment) => sum + comment.replies.length);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(EpisodeDetailComments oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episodeId != widget.episodeId ||
        oldWidget.reloadToken != widget.reloadToken) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    var generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    var response = await ref
        .read(bangumiRepositoryProvider)
        .getEpisodeComments(widget.episodeId);
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      if (response.code == 0 && response.data != null) {
        _comments = response.data!;
      } else {
        _error = response.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(context),
        if (_loading) const ProgressBar(strokeWidth: 2),
        if (_error != null && _comments.isNotEmpty)
          SubjectDetailModuleStatus(message: _error!, onRetry: _load),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  /// 总数与刷新集中在标题栏，列表只保留吐槽内容本身。
  Widget _buildToolbar(BuildContext context) {
    var label = _loading ? '正在加载吐槽' : '刷新吐槽';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          Text('吐槽箱', style: BTTypography.bodyStrong(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _loading ? '正在加载' : '共 ${widget.total} 条（含 $_replyCount 条回复）',
              style: BTTypography.caption(context),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Tooltip(
            message: label,
            child: Semantics(
              label: label,
              child: IconButton(
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 14,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : const Icon(FluentIcons.refresh, size: 14),
                onPressed: _loading ? null : _load,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_comments.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: SubjectDetailModuleStatus(
          loading: _loading,
          message: _loading ? '正在加载吐槽' : (_error ?? '暂无吐槽'),
          onRetry: !_loading && _error != null ? _load : null,
        ),
      );
    }
    return ListView.separated(
      primary: false,
      key: PageStorageKey('episode-${widget.episodeId}-comments'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _CommentCard(_comments[index]),
    );
  }
}

/// 单条章节吐槽：正文可选中，回复跟随在正文下方。
class _CommentCard extends StatefulWidget {
  const _CommentCard(this.comment);

  final BangumiEpisodeComment comment;

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
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
            _CommentHeader(user: comment.user, createdAt: comment.createdAt),
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
    required this.imageIndexBase,
    required this.onImageTap,
  });

  final BangumiEpisodeCommentReply reply;

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

/// 吐槽标题行：头像、昵称与发布时间。
class _CommentHeader extends StatelessWidget {
  const _CommentHeader({
    required this.user,
    required this.createdAt,
    this.avatarSize = 36,
  });

  final BangumiCommentUser user;

  /// 发布时间，Unix 秒
  final int createdAt;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    var name = replaceEscape(
      user.nickname.isEmpty ? user.username : user.nickname,
    );
    var profile =
        '${BtrBangumiApi.siteBaseUrl}/user/'
        '${Uri.encodeComponent(user.username)}';
    var time = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000).toLocal();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildAvatar(context, name, profile),
        const SizedBox(width: 10),
        // 昵称按内容宽度自适应，剩余空间留给右侧时间
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Tooltip(
              message: user.username,
              child: HyperlinkButton(
                onPressed: () => unawaited(launchUrlString(profile)),
                child: Text(
                  name,
                  style: BTTypography.bodyStrong(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          DateFormat('yyyy-MM-dd HH:mm').format(time),
          style: BTTypography.caption(context),
        ),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context, String name, String profile) {
    var label = '在浏览器中查看 $name 的主页';
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => unawaited(launchUrlString(profile)),
            child: BtBangumiCover(
              imageUrl: user.avatar.medium,
              width: avatarSize,
              height: avatarSize,
              maxRequestEdge: BangumiCoverUrl.thumbMaxEdge,
              borderRadius: BTRadius.mediumBR,
              progressSize: avatarSize * 0.4,
              errorBuilder: (context, {err}) => SizedBox.square(
                dimension: avatarSize,
                child: Icon(FluentIcons.contact, size: avatarSize * 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
