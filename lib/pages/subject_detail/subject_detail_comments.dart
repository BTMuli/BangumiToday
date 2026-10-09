// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../core/utils/bangumi_utils.dart';
import '../../core/utils/tool_func.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../providers/app_providers.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import '../../widgets/bangumi/bt_comment_content.dart';
import '../../widgets/bangumi/comment_image_viewer.dart';
import 'subject_detail_colors.dart';
import 'subject_detail_module_status.dart';
import 'subject_detail_refreshable.dart';

class SubjectDetailComments extends ConsumerStatefulWidget {
  const SubjectDetailComments({super.key, required this.subjectId});

  final int subjectId;

  @override
  ConsumerState<SubjectDetailComments> createState() =>
      _SubjectDetailCommentsState();
}

class _SubjectDetailCommentsState extends ConsumerState<SubjectDetailComments>
    with SubjectDetailRefreshable {
  static const _limit = 20;

  /// 筛选顺序与条目页的收藏状态一致，「全部」排在最前。
  static const _filters = <BangumiCollectionType?>[
    null,
    BangumiCollectionType.wish,
    BangumiCollectionType.collect,
    BangumiCollectionType.doing,
    BangumiCollectionType.onHold,
    BangumiCollectionType.dropped,
  ];

  final ScrollController _scrollController = ScrollController();
  List<BangumiSubjectComment> _comments = [];
  BangumiCollectionType? _filter;
  int? _total;
  int _offset = 0;
  int _generation = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load(0));
  }

  @override
  void didUpdateWidget(SubjectDetailComments oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectId != widget.subjectId) {
      _filter = null;
      _comments = [];
      _total = null;
      _offset = 0;
      unawaited(_load(0));
    }
  }

  void _changeFilter(BangumiCollectionType? filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _comments = [];
      _offset = 0;
      _total = null;
    });
    unawaited(_load(0));
  }

  Future<void> _load(int offset) async {
    var generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    var response = await ref
        .read(bangumiRepositoryProvider)
        .getSubjectComments(
          widget.subjectId,
          type: _filter,
          offset: offset,
          limit: _limit,
        );
    if (!mounted || generation != _generation) return;
    var page = response.data;
    setState(() {
      _loading = false;
      if (response.code == 0 && page != null) {
        _comments = page.data;
        _offset = page.offset;
        _total = page.total;
      } else {
        _error = response.message;
      }
    });
    if (response.code == 0 && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Future<void> refresh() => _load(_offset);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(context),
        if (_loading) const ProgressBar(strokeWidth: 2),
        if (_error != null && _comments.isNotEmpty)
          SubjectDetailModuleStatus(message: _error!, onRetry: refresh),
        Expanded(child: _buildContent()),
      ],
    );
  }

  bool get _hasPages => (_total ?? 0) > _limit || _offset > 0;

  /// 筛选、翻页、总数与刷新集中在标题栏，列表只保留吐槽内容本身。
  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('收藏状态', style: BTTypography.bodyStrong(context)),
                for (var filter in _filters)
                  _CommentFilterChip(
                    label: filter?.label ?? '全部',
                    tooltip: filter == null
                        ? '显示全部吐槽'
                        : '只看「${filter.label}」的吐槽',
                    selected: _filter == filter,
                    // 切换筛选不等待上一次请求，旧响应由代次号丢弃。
                    onPressed: () => _changeFilter(filter),
                  ),
                if (_hasPages) ...[
                  const SizedBox(width: 4),
                  _buildPagination(context),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (_total != null) ...[
            Text('共 $_total 条', style: BTTypography.caption(context)),
            const SizedBox(width: 6),
          ],
          _action(
            label: _loading ? '正在加载吐槽' : '刷新吐槽',
            icon: FluentIcons.refresh,
            loading: _loading,
            onPressed: _loading ? null : refresh,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_comments.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: SubjectDetailModuleStatus(
          loading: _loading,
          message: _loading
              ? '正在加载吐槽'
              : (_error ??
                    (_filter == null ? '暂无吐槽' : '暂无${_filter!.label}状态的吐槽')),
          onRetry: !_loading && _error != null ? refresh : null,
        ),
      );
    }
    return ListView.separated(
      primary: false,
      key: PageStorageKey('subject-${widget.subjectId}-comments'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _CommentCard(_comments[index]),
    );
  }

  /// 翻页跟在收藏状态筛选之后，与筛选同一行排布。
  Widget _buildPagination(BuildContext context) {
    var pages = ((_total ?? 0) / _limit).ceil().clamp(1, 1 << 30);
    var page = _offset ~/ _limit + 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _action(
          label: '上一页',
          icon: FluentIcons.chevron_left,
          onPressed: _loading || _offset == 0
              ? null
              : () => _load((_offset - _limit).clamp(0, _offset)),
        ),
        const SizedBox(width: 2),
        Text('$page / $pages', style: BTTypography.caption(context)),
        const SizedBox(width: 2),
        _action(
          label: '下一页',
          icon: FluentIcons.chevron_right,
          onPressed: _loading || _offset + _limit >= (_total ?? 0)
              ? null
              : () => _load(_offset + _limit),
        ),
      ],
    );
  }

  Widget _action({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool loading = false,
  }) => Tooltip(
    message: label,
    child: Semantics(
      label: label,
      child: IconButton(
        icon: loading
            ? const SizedBox.square(
                dimension: 14,
                child: ProgressRing(strokeWidth: 2),
              )
            : Icon(icon, size: 14),
        onPressed: onPressed,
      ),
    ),
  );
}

/// 与详情页其他筛选一致的胶囊筛选块。
class _CommentFilterChip extends StatefulWidget {
  const _CommentFilterChip({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  State<_CommentFilterChip> createState() => _CommentFilterChipState();
}

class _CommentFilterChipState extends State<_CommentFilterChip> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    var selected = widget.selected;
    var enabled = widget.onPressed != null;
    var shape = StadiumBorder(
      side: BorderSide(color: selected ? accent : BTColors.divider(context)),
    );
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        toggled: selected,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Button(
            onPressed: widget.onPressed,
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              ),
              shape: WidgetStatePropertyAll(shape),
              foregroundColor: WidgetStatePropertyAll(
                selected ? Colors.white : BTColors.textSecondary(context),
              ),
              backgroundColor: WidgetStatePropertyAll(
                selected
                    ? accent
                    : (_hovered && enabled
                          ? accent.withValues(alpha: 0.08)
                          : Colors.transparent),
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 单条吐槽：头像、昵称、收藏状态、评分与时间构成标题行，正文可选中。
class _CommentCard extends StatefulWidget {
  const _CommentCard(this.comment);

  final BangumiSubjectComment comment;

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  var _hovered = false;

  /// 本条吐槽的图片集合，列表复用 State 时按评论实例重算
  BangumiSubjectComment? _cachedComment;
  late CommentImageSet _images;
  late int _imageBase;

  void _syncImages() {
    var comment = widget.comment;
    if (identical(_cachedComment, comment)) return;
    _cachedComment = comment;
    var images = CommentImageSet();
    _imageBase = images.add(comment.comment);
    _images = images;
  }

  @override
  Widget build(BuildContext context) {
    var comment = widget.comment;
    var user = comment.user;
    var name = replaceEscape(
      user.nickname.isEmpty ? user.username : user.nickname,
    );
    var profile =
        '${BtrBangumiApi.siteBaseUrl}/user/'
        '${Uri.encodeComponent(user.username)}';
    var content = comment.comment.trim();
    var updatedAt = DateTime.fromMillisecondsSinceEpoch(
      comment.updatedAt * 1000,
    ).toLocal();
    var accent = FluentTheme.of(context).accentColor;
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(context, name, profile),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildMeta(context, name, profile)),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(updatedAt),
                        style: BTTypography.caption(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (content.isEmpty)
                    Text('未填写吐槽内容', style: BTTypography.caption(context))
                  else
                    BtCommentContent(
                      text: content,
                      imageIndexBase: _imageBase,
                      onImageTap: (index) =>
                          unawaited(_images.show(context, index)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
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
              imageUrl: widget.comment.user.avatar.medium,
              width: 36,
              height: 36,
              maxRequestEdge: BangumiCoverUrl.thumbMaxEdge,
              borderRadius: BTRadius.mediumBR,
              progressSize: 14,
              errorBuilder: (context, {err}) => const SizedBox.square(
                dimension: 36,
                child: Icon(FluentIcons.contact, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeta(BuildContext context, String name, String profile) {
    var comment = widget.comment;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tooltip(
          message: comment.user.username,
          child: HyperlinkButton(
            onPressed: () => unawaited(launchUrlString(profile)),
            child: Text(name, style: BTTypography.bodyStrong(context)),
          ),
        ),
        _CollectionTypeChip(type: comment.type),
        if (comment.rate > 0) _CommentRate(rate: comment.rate),
      ],
    );
  }
}

/// 收藏状态标签：沿用网站的语义配色，避免所有状态共用主题色。
class _CollectionTypeChip extends StatelessWidget {
  const _CollectionTypeChip({required this.type});

  final BangumiCollectionType type;

  Color _foreground(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    switch (type) {
      case BangumiCollectionType.unknown:
        return BTColors.textTertiary(context);
      case BangumiCollectionType.wish:
        return isDark ? const Color(0xFF4CC2FF) : BTColors.info;
      case BangumiCollectionType.collect:
        return BTColors.successLight(context);
      case BangumiCollectionType.doing:
        return FluentTheme.of(context).accentColor;
      case BangumiCollectionType.onHold:
        return BTColors.warningLight(context);
      case BangumiCollectionType.dropped:
        return BTColors.errorLight(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    var color = _foreground(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BTRadius.smallBR,
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// 吐槽评分：网站用五星表示 10 分制，这里额外给出精确分数。
class _CommentRate extends StatelessWidget {
  const _CommentRate({required this.rate});

  final int rate;

  @override
  Widget build(BuildContext context) {
    var label = '评分 $rate 分 · ${getBangumiRateLabel(rate.toDouble())}';
    return Tooltip(
      message: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RatingControl(
            rating: rate / 2,
            iconSize: 12,
            starSpacing: 1,
            ratedIconColor: FluentTheme.of(context).accentColor,
            unratedIconColor: BTColors.textTertiary(
              context,
            ).withValues(alpha: 0.4),
            semanticLabel: label,
          ),
          const SizedBox(width: 6),
          Text('$rate 分', style: BTTypography.caption(context)),
        ],
      ),
    );
  }
}
