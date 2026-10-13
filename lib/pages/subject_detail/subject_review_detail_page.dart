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
import '../../widgets/bangumi/bt_comment_content.dart';
import '../../widgets/bangumi/comment_image_viewer.dart';
import '../../widgets/common/bt_content_frame.dart';
import 'detail_comment_author.dart';
import 'detail_discussion_comment.dart';
import 'subject_detail_colors.dart';
import 'subject_detail_module_status.dart';
import 'subject_review_widgets.dart';

enum _ReviewTab {
  body('正文'),
  comments('评论');

  const _ReviewTab(this.label);

  final String label;
}

/// 与剧集详情一样作为条目详情的子页面，返回时保留条目页状态。
class SubjectReviewDetailPage extends ConsumerStatefulWidget {
  const SubjectReviewDetailPage({
    super.key,
    required this.entryId,
    required this.subjectTitle,
    required this.onBack,
  });

  final int entryId;
  final String subjectTitle;
  final VoidCallback onBack;

  @override
  ConsumerState<SubjectReviewDetailPage> createState() =>
      _SubjectReviewDetailPageState();
}

class _SubjectReviewDetailPageState
    extends ConsumerState<SubjectReviewDetailPage> {
  final ScrollController _bodyScrollController = ScrollController();
  final ScrollController _commentsScrollController = ScrollController();
  _ReviewTab _selectedTab = _ReviewTab.body;
  BangumiReviewDetail? _detail;
  List<BangumiEpisodeComment> _comments = [];
  CommentImageSet _images = CommentImageSet();
  bool _loading = true;
  bool _commentsLoading = true;
  String? _error;
  String? _commentsError;
  int _generation = 0;
  int _commentsGeneration = 0;

  String get _pageUrl => '${BtrBangumiApi.siteBaseUrl}/blog/${widget.entryId}';

  ScrollController get _activeScrollController =>
      _selectedTab == _ReviewTab.body
      ? _bodyScrollController
      : _commentsScrollController;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(SubjectReviewDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryId != widget.entryId) {
      _selectedTab = _ReviewTab.body;
      _detail = null;
      _comments = [];
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _bodyScrollController.dispose();
    _commentsScrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToTop() async {
    var controller = _activeScrollController;
    if (!controller.hasClients) return;
    await controller.animateTo(
      0,
      duration: BTTheme.animationDurationFast,
      curve: BTTheme.animationCurve,
    );
  }

  Future<void> _load() async {
    await Future.wait([_loadDetail(), _loadComments()]);
  }

  Future<void> _loadDetail() async {
    var generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    var response = await ref
        .read(bangumiRepositoryProvider)
        .getReviewDetail(widget.entryId);
    if (!mounted || generation != _generation) return;
    var detail = response.data;
    setState(() {
      _loading = false;
      if (response.code == 0 && detail != null) {
        _detail = detail;
        _images = CommentImageSet()..add(detail.content);
      } else {
        _error = response.message;
      }
    });
  }

  Future<void> _loadComments() async {
    var generation = ++_commentsGeneration;
    setState(() {
      _commentsLoading = true;
      _commentsError = null;
    });
    var response = await ref
        .read(bangumiRepositoryProvider)
        .getReviewComments(widget.entryId);
    if (!mounted || generation != _commentsGeneration) return;
    setState(() {
      _commentsLoading = false;
      if (response.code == 0 && response.data != null) {
        _comments = response.data!;
      } else {
        _commentsError = response.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) => ScaffoldPage(
    header: _buildHeader(context),
    content: Stack(
      fit: StackFit.expand,
      children: [
        BTContentFrame(maxWidth: 1440, child: _buildContent(context)),
        if (_loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(child: ProgressBar(strokeWidth: 3)),
          ),
      ],
    ),
  );

  Widget _buildHeader(BuildContext context) {
    var refreshing = _loading || _commentsLoading;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        bottom: 4,
        end: PageHeader.horizontalPadding(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SubjectReviewAction(
                label: '返回条目详情',
                icon: FluentIcons.back,
                size: 16,
                onPressed: widget.onBack,
              ),
              Expanded(
                child: Text(
                  '评论详情',
                  style: FluentTheme.of(context).typography.subtitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AnimatedBuilder(
                animation: Listenable.merge([
                  _bodyScrollController,
                  _commentsScrollController,
                ]),
                builder: (context, child) {
                  var controller = _activeScrollController;
                  var canScrollToTop =
                      controller.hasClients && controller.offset > 0;
                  return SubjectReviewAction(
                    label: canScrollToTop ? '回到顶部' : '已在顶部',
                    icon: FluentIcons.chevron_up,
                    size: 16,
                    onPressed: canScrollToTop ? _scrollToTop : null,
                  );
                },
              ),
              const SizedBox(width: 8),
              SubjectReviewAction(
                label: '在浏览器中打开评论',
                icon: FluentIcons.link,
                size: 16,
                onPressed: () => unawaited(launchUrlString(_pageUrl)),
              ),
              const SizedBox(width: 8),
              SubjectReviewAction(
                label: refreshing ? '正在刷新' : '刷新页面',
                icon: FluentIcons.refresh,
                size: 16,
                loading: refreshing,
                onPressed: refreshing ? null : _load,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: PageHeader.horizontalPadding(context),
            ),
            child: _buildTabs(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    var commentCount = _commentsLoading || _commentsError != null
        ? _detail?.replies
        : _comments.fold(_comments.length, (sum, item) {
            return sum + item.replies.length;
          });
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var tab in _ReviewTab.values)
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _selectedTab == tab ? accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Semantics(
              selected: _selectedTab == tab,
              child: HyperlinkButton(
                onPressed: () => setState(() => _selectedTab = tab),
                child: Text(
                  tab == _ReviewTab.comments && commentCount != null
                      ? '${tab.label} · $commentCount'
                      : tab.label,
                  style: BTTypography.body(context).copyWith(
                    color: _selectedTab == tab
                        ? BTColors.textPrimary(context)
                        : BTColors.textSecondary(context),
                    fontWeight: _selectedTab == tab
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        if (_selectedTab == _ReviewTab.comments)
          SubjectReviewAction(
            label: _commentsLoading ? '正在刷新评论' : '刷新评论',
            icon: FluentIcons.refresh,
            loading: _commentsLoading,
            onPressed: _commentsLoading ? null : _loadComments,
          ),
      ],
    );
  }

  Widget _buildReviewCard(BuildContext context, BangumiReviewDetail detail) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: HyperlinkButton(
              style: const ButtonStyle(
                padding: WidgetStatePropertyAll(EdgeInsets.zero),
                backgroundColor: WidgetStatePropertyAll(Colors.transparent),
              ),
              onPressed: widget.onBack,
              child: Text(
                widget.subjectTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            replaceEscape(detail.title),
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 8),
          DetailCommentAuthor(user: detail.user),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _meta(context, '发布于 ${_date(detail.createdAt)}'),
              if (detail.updatedAt != detail.createdAt)
                _meta(context, '更新于 ${_date(detail.updatedAt)}'),
              _meta(context, '${detail.views} 次浏览'),
              _meta(context, '${detail.replies} 条回复'),
              for (var tag in detail.tags)
                _meta(context, '#${replaceEscape(tag)}'),
            ],
          ),
          const SizedBox(height: 12),
          BtCommentContent(
            key: ValueKey(detail.content),
            text: detail.content,
            onImageTap: (index) => unawaited(_images.show(context, index)),
          ),
        ],
      ),
    );
  }

  String _date(int seconds) => DateFormat(
    'yyyy-MM-dd HH:mm',
  ).format(DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal());

  Widget _meta(BuildContext context, String text) =>
      Text(text, style: BTTypography.caption(context));

  BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
    color: SubjectDetailColors.card(context),
    borderRadius: BTRadius.mediumBR,
    border: Border.all(color: BTColors.divider(context)),
  );

  Widget _buildContent(BuildContext context) {
    var detail = _detail;
    if (detail == null) {
      return Center(
        child: SubjectDetailModuleStatus(
          loading: _loading,
          message: _loading ? '正在加载评论详情' : (_error ?? '加载评论详情失败'),
          onRetry: _loading ? null : _loadDetail,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: SubjectDetailColors.content(context),
          borderRadius: BTRadius.mediumBR,
          border: Border.all(color: BTColors.divider(context)),
        ),
        child: IndexedStack(
          sizing: StackFit.expand,
          index: _selectedTab.index,
          children: [
            SingleChildScrollView(
              primary: false,
              controller: _bodyScrollController,
              key: PageStorageKey('review-${widget.entryId}-body'),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    SubjectDetailModuleStatus(
                      message: _error!,
                      onRetry: _loadDetail,
                    ),
                  _buildReviewCard(context, detail),
                ],
              ),
            ),
            ListView.builder(
              primary: false,
              controller: _commentsScrollController,
              key: PageStorageKey('review-${widget.entryId}-comments'),
              padding: const EdgeInsets.all(8),
              itemCount: _comments.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _buildCommentsStatus();
                var comment = _comments[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DetailDiscussionComment(
                    comment,
                    key: ValueKey(comment.id),
                    pageUrl: _pageUrl,
                    floor: index,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsStatus() {
    if (_commentsLoading) return const ProgressBar(strokeWidth: 2);
    if (_commentsError != null) {
      return SubjectDetailModuleStatus(
        message: _commentsError!,
        onRetry: _loadComments,
      );
    }
    if (_comments.isEmpty) {
      return const SubjectDetailModuleStatus(message: '暂无评论');
    }
    return const SizedBox.shrink();
  }
}
