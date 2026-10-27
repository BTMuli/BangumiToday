// Dart imports:
import 'dart:math' as math;

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/layout/responsive.dart';
import '../../core/theme/bt_theme.dart';
import '../../core/utils/tool_func.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../providers/app_providers.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../ui/bt_dialog.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import 'subject_detail_colors.dart';
import 'subject_detail_module_status.dart';
import 'subject_detail_refreshable.dart';

class SubjectDetailRelation extends ConsumerStatefulWidget {
  final int subjectId;

  const SubjectDetailRelation(this.subjectId, {super.key});

  @override
  ConsumerState<SubjectDetailRelation> createState() =>
      _SubjectDetailRelationState();
}

class _SubjectDetailRelationState extends ConsumerState<SubjectDetailRelation>
    with AutomaticKeepAliveClientMixin, SubjectDetailRefreshable {
  static const _cardExtent = 120.0;
  static const _spacing = 8.0;

  int get subjectId => widget.subjectId;

  final ScrollController _scrollController = ScrollController();
  List<BangumiSubjectRelation> relations = [];
  bool _loading = true;
  bool _refreshing = false;
  String? _loadError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await load();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> load({bool reportError = false}) async {
    if (!mounted || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      var repository = ref.read(bangumiRepositoryProvider);
      var resp = await repository.getSubjectRelations(subjectId);
      if (!mounted) return;
      if (resp.code != 0 || resp.data == null) {
        setState(() {
          _loading = false;
          _loadError = resp.message;
        });
        if (reportError) await showRespErr(resp, context);
        return;
      }
      setState(() {
        relations = resp.data!;
        _loading = false;
        _loadError = null;
      });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// 内容工具栏和详情页刷新按钮共用入口，刷新时保留已有条目。
  @override
  Future<void> refresh() => load(reportError: true);

  Widget buildCardInfo(BangumiSubjectRelation data) {
    var title = replaceEscape(data.nameCn.isEmpty ? data.name : data.nameCn);
    var originalTitle = replaceEscape(data.name);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Tooltip(
            message: title == originalTitle ? title : '$title\n$originalTitle',
            child: Text(
              title,
              style: BTTypography.bodyStrong(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Text(
            data.relation,
            style: BTTypography.caption(
              context,
            ).copyWith(color: FluentTheme.of(context).accentColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'ID: ${data.id}',
                  style: BTTypography.caption(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: '查看详情',
                child: IconButton(
                  icon: Icon(
                    FluentIcons.info,
                    size: 14,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  onPressed: () => ref
                      .read(navStoreProvider.notifier)
                      .addNavItemB(
                        type: data.type.label,
                        subject: data.id,
                        paneTitle: data.nameCn == '' ? data.name : data.nameCn,
                      ),
                ),
              ),
              SizedBox(width: 4),
              Tooltip(
                message: '打开链接',
                child: IconButton(
                  icon: Icon(
                    FluentIcons.link,
                    size: 14,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  onPressed: () {
                    launchUrlString(
                      '${BtrBangumiApi.siteBaseUrl}/subject/${data.id}',
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildCover(BangumiImages images) {
    return BtBangumiCover(
      imageUrl: images.large,
      width: 80,
      height: 120,
      maxRequestEdge: BangumiCoverUrl.thumbMaxEdge,
      borderRadius: BTRadius.smallBR,
      progressSize: 16,
      errorBuilder: (context, {err}) => Container(
        width: 80,
        height: 120,
        color: SubjectDetailColors.card(context),
        child: Icon(
          FluentIcons.photo_error,
          size: 20,
          color: BTColors.textTertiary(context),
        ),
      ),
    );
  }

  Widget buildRelationCard(BangumiSubjectRelation data) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    var hasImage = data.images.large.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: SubjectDetailColors.card(context),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          if (hasImage) ...[buildCover(data.images), SizedBox(width: 8)],
          Expanded(child: buildCardInfo(data)),
        ],
      ),
    );
  }

  IconData _typeIcon(BangumiSubjectType type) => switch (type) {
    BangumiSubjectType.book => FluentIcons.reading_mode,
    BangumiSubjectType.anime => FluentIcons.video,
    BangumiSubjectType.music => FluentIcons.music_note,
    BangumiSubjectType.game => FluentIcons.game,
    BangumiSubjectType.real => FluentIcons.t_v_monitor,
  };

  Future<void> _scrollToGroup(double offset) async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: BTTheme.animationDurationNormal,
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildToolbar(Map<BangumiSubjectType, double> offsets) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: BTColors.divider(context))),
      ),
      child: Row(
        children: [
          Text(
            _loading ? '关联条目' : '共 ${relations.length} 个关联条目',
            style: BTTypography.caption(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: [
                for (var entry in offsets.entries)
                  Tooltip(
                    message: '跳转到${entry.key.label}',
                    child: IconButton(
                      icon: Icon(
                        _typeIcon(entry.key),
                        size: 14,
                        semanticLabel: '跳转到${entry.key.label}',
                      ),
                      onPressed: () => _scrollToGroup(entry.value),
                    ),
                  ),
                Tooltip(
                  message: _refreshing ? '正在刷新关联条目' : '刷新关联条目',
                  child: Semantics(
                    label: '刷新关联条目',
                    child: IconButton(
                      icon: _refreshing
                          ? const SizedBox.square(
                              dimension: 14,
                              child: ProgressRing(strokeWidth: 2),
                            )
                          : const Icon(FluentIcons.refresh, size: 14),
                      onPressed: _refreshing ? null : refresh,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRelationGroup(
    BangumiSubjectType type,
    List<BangumiSubjectRelation> items,
    SliverGridDelegate gridDelegate,
    double headerExtent,
  ) {
    return SliverMainAxisGroup(
      slivers: [
        SliverLayoutBuilder(
          builder: (context, constraints) {
            var isPinned = constraints.scrollOffset > 0;
            return PinnedHeaderSliver(
              child: Semantics(
                header: true,
                child: Container(
                  height: headerExtent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: SubjectDetailColors.content(context),
                    border: isPinned
                        ? Border(
                            bottom: BorderSide(
                              color: BTColors.divider(context),
                            ),
                          )
                        : null,
                    boxShadow: isPinned ? BTTheme.shadow(context) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _typeIcon(type),
                        size: 14,
                        color: BTColors.textSecondary(context),
                      ),
                      const SizedBox(width: 6),
                      Text(type.label, style: BTTypography.bodyStrong(context)),
                      const SizedBox(width: 8),
                      Text(
                        '${items.length}',
                        style: BTTypography.caption(context),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, _spacing),
          sliver: SliverGrid.builder(
            gridDelegate: gridDelegate,
            itemCount: items.length,
            itemBuilder: (context, index) => buildRelationCard(items[index]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var groups = <BangumiSubjectType, List<BangumiSubjectRelation>>{};
    for (var relation in relations) {
      groups.putIfAbsent(relation.type, () => []).add(relation);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = BTBreakpoints.getGridColumns(constraints.maxWidth - 16);
        var headerExtent = math.max(
          36.0,
          MediaQuery.textScalerOf(context).scale(14) * 1.5 + 12,
        );
        var gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: _spacing,
          mainAxisSpacing: _spacing,
          mainAxisExtent: _cardExtent,
        );
        // 固定行高的网格可直接计算分组位置，尚未挂载的分类也能准确跳转。
        var offsets = <BangumiSubjectType, double>{};
        var offset = 0.0;
        for (var type in BangumiSubjectType.values) {
          var items = groups[type];
          if (items == null) continue;
          offsets[type] = offset;
          var rows = (items.length / columns).ceil();
          offset += headerExtent + 4 + rows * (_cardExtent + _spacing);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildToolbar(offsets),
            Expanded(
              child: _loading || relations.isEmpty
                  ? SubjectDetailModuleStatus(
                      loading: _loading,
                      message: _loading
                          ? '正在加载关联条目'
                          : (_loadError == null
                                ? '暂无关联条目'
                                : '关联条目加载失败：$_loadError'),
                    )
                  : CustomScrollView(
                      key: PageStorageKey('subject-$subjectId-relations'),
                      controller: _scrollController,
                      primary: false,
                      slivers: [
                        for (var type in offsets.keys)
                          buildRelationGroup(
                            type,
                            groups[type]!,
                            gridDelegate,
                            headerExtent,
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}
