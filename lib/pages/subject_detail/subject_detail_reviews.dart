// Dart imports:
import 'dart:async';

// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../core/utils/bangumi_review_preview.dart';
import '../../core/utils/tool_func.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../providers/app_providers.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import '../../widgets/bangumi/bt_comment_image.dart';
import 'detail_comment_author.dart';
import 'subject_detail_colors.dart';
import 'subject_detail_module_status.dart';
import 'subject_detail_refreshable.dart';
import 'subject_review_widgets.dart';

class SubjectDetailReviews extends ConsumerStatefulWidget {
  const SubjectDetailReviews({
    super.key,
    required this.subjectId,
    required this.onOpenReview,
  });

  final int subjectId;
  final ValueChanged<int> onOpenReview;

  @override
  ConsumerState<SubjectDetailReviews> createState() =>
      _SubjectDetailReviewsState();
}

class _SubjectDetailReviewsState extends ConsumerState<SubjectDetailReviews>
    with SubjectDetailRefreshable {
  static const _limit = 20;
  final ScrollController _scrollController = ScrollController();
  List<BangumiSubjectReview> _reviews = [];
  int? _total;
  int _offset = 0;
  int _requestedOffset = 0;
  int _generation = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load(0));
  }

  @override
  void didUpdateWidget(SubjectDetailReviews oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectId != widget.subjectId) {
      _reviews = [];
      _total = null;
      _offset = 0;
      unawaited(_load(0));
    }
  }

  Future<void> _load(int offset) async {
    var generation = ++_generation;
    _requestedOffset = offset;
    setState(() {
      _loading = true;
      _error = null;
    });
    var response = await ref
        .read(bangumiRepositoryProvider)
        .getSubjectReviews(widget.subjectId, offset: offset, limit: _limit);
    if (!mounted || generation != _generation) return;
    var page = response.data;
    setState(() {
      _loading = false;
      if (response.code == 0 && page != null) {
        _reviews = page.data;
        _total = page.total;
        _offset = page.offset;
      } else {
        _error = response.message;
      }
    });
    if (response.code == 0 && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Future<void> refresh() => _load(_requestedOffset);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _buildToolbar(context),
      if (_loading) const ProgressBar(strokeWidth: 2),
      if (_error != null && _reviews.isNotEmpty)
        SubjectDetailModuleStatus(message: _error!, onRetry: refresh),
      Expanded(
        child: _reviews.isEmpty
            ? Align(
                alignment: Alignment.topCenter,
                child: SubjectDetailModuleStatus(
                  loading: _loading,
                  message: _loading ? '正在加载评论' : (_error ?? '暂无评论'),
                  onRetry: !_loading && _error != null ? refresh : null,
                ),
              )
            : ListView.separated(
                primary: false,
                key: PageStorageKey('subject-${widget.subjectId}-reviews'),
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _reviews.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _ReviewCard(
                  review: _reviews[index],
                  onOpen: widget.onOpenReview,
                ),
              ),
      ),
    ],
  );

  Widget _buildToolbar(BuildContext context) {
    var pages = ((_total ?? 0) / _limit).ceil().clamp(1, 1 << 30);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('评论', style: BTTypography.bodyStrong(context)),
          if (_total != null)
            Text('共 $_total 篇', style: BTTypography.caption(context)),
          if (pages > 1 || _offset > 0) ...[
            SubjectReviewAction(
              label: '上一页',
              icon: FluentIcons.chevron_left,
              onPressed: _loading || _offset == 0
                  ? null
                  : () => _load((_offset - _limit).clamp(0, _offset)),
            ),
            Text(
              '${_offset ~/ _limit + 1} / $pages',
              style: BTTypography.caption(context),
            ),
            SubjectReviewAction(
              label: '下一页',
              icon: FluentIcons.chevron_right,
              onPressed: _loading || _offset + _limit >= (_total ?? 0)
                  ? null
                  : () => _load(_offset + _limit),
            ),
          ],
          SubjectReviewAction(
            label: '在浏览器中打开条目评论',
            icon: FluentIcons.link,
            onPressed: () => unawaited(
              launchUrlString(
                '${BtrBangumiApi.nextBaseUrl}/subject/'
                '${widget.subjectId}/reviews',
              ),
            ),
          ),
          SubjectReviewAction(
            label: _loading ? '正在加载评论' : '刷新评论',
            icon: FluentIcons.refresh,
            loading: _loading,
            onPressed: _loading ? null : refresh,
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onOpen});

  final BangumiSubjectReview review;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    var entry = review.entry;
    var preview = BangumiReviewPreview.fromSummary(entry.summary);
    var images = preview.imageUrls
        .map(resolveBangumiCommentImage)
        .whereType<String>()
        .take(2)
        .toList();
    if (images.isEmpty && entry.icon.trim().isNotEmpty) {
      images.add(
        BangumiCoverUrl.resolve(
          entry.icon,
          maxEdge: BangumiCoverUrl.thumbMaxEdge,
        ),
      );
    }
    var time = DateTime.fromMillisecondsSinceEpoch(
      entry.createdAt * 1000,
    ).toLocal();
    var accent = FluentTheme.of(context).accentColor;
    return Button(
      onPressed: () => onOpen(entry.id),
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.all(14)),
        backgroundColor: WidgetStatePropertyAll(
          SubjectDetailColors.card(context),
        ),
        shape: WidgetStateProperty.resolveWith(
          (states) => RoundedRectangleBorder(
            borderRadius: BTRadius.mediumBR,
            side: BorderSide(
              color: states.isHovered || states.isFocused
                  ? accent.withValues(alpha: 0.45)
                  : BTColors.divider(context),
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: DetailCommentAuthor(user: review.user)),
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
                  Text(
                    '${entry.replies} 条回复',
                    style: BTTypography.caption(context),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              SubjectReviewAction(
                label: '查看评论详情',
                icon: FluentIcons.chevron_right,
                onPressed: () => onOpen(entry.id),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      replaceEscape(entry.title),
                      textAlign: TextAlign.start,
                      style: BTTypography.subtitle(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (preview.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        preview.text,
                        textAlign: TextAlign.start,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: BTTypography.body(context).copyWith(height: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
              for (var url in images) _buildThumbnail(context, url),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, String url) =>
      CachedNetworkImage(
        imageUrl: url,
        memCacheWidth: BangumiCoverUrl.cachePixels(
          72,
          MediaQuery.devicePixelRatioOf(context),
        ),
        imageBuilder: (context, provider) => Padding(
          padding: const EdgeInsets.only(left: 14),
          child: ClipRRect(
            borderRadius: BTRadius.mediumBR,
            child: Image(
              image: provider,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
        ),
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      );
}
