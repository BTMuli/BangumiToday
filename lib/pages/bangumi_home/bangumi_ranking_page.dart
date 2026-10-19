// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/errors/error_handler.dart';
import '../../core/theme/bt_theme.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_subject_browse.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../widgets/common/bt_icon_toggle_group.dart';
import '../../widgets/common/empty_state.dart';
import '../subject_search/subject_search_page.dart';
import 'bangumi_ranking_card.dart';
import 'bangumi_ranking_provider.dart';
import 'bangumi_ranking_time_filter.dart';

/// 排行榜切换与首页入口共用同一份图标映射。
extension BangumiRankingSortIcon on BangumiSubjectBrowseSort {
  IconData get icon => switch (this) {
    BangumiSubjectBrowseSort.trends => FluentIcons.flame_solid,
    BangumiSubjectBrowseSort.rank => FluentIcons.trophy,
  };
}

class BangumiRankingPage extends ConsumerStatefulWidget {
  const BangumiRankingPage({
    super.key,
    required this.sort,
    required this.onSortChanged,
  });

  final BangumiSubjectBrowseSort sort;
  final ValueChanged<BangumiSubjectBrowseSort> onSortChanged;

  @override
  ConsumerState<BangumiRankingPage> createState() => _BangumiRankingPageState();
}

class _BangumiRankingPageState extends ConsumerState<BangumiRankingPage> {
  BangumiSubjectBrowseSort get _sort => widget.sort;
  final _pages = <BangumiSubjectBrowseSort, int>{};

  /// 时间筛选由热度与评分排行共用，切换榜单时保留。
  var _time = BangumiSubjectBrowseTime.all;

  int get _page => _pages[_sort] ?? 1;
  BangumiRankingQuery get _query =>
      (sort: _sort, page: _page, year: _time.year, month: _time.month);

  void _refresh() {
    setState(() => _pages[_sort] = 1);
    ref.invalidate(bangumiRankingProvider);
  }

  void _changeTime(BangumiSubjectBrowseTime time) {
    if (time == _time) return;
    setState(() {
      _time = time;
      _pages.clear();
    });
  }

  String get _browserUrl {
    var query = 'sort=${_sort.name}&page=$_page';
    var year = _time.year;
    if (year == null) {
      return '${BtrBangumiApi.siteBaseUrl}/anime/browser/?$query';
    }
    var month = _time.month;
    var airtime = month == null ? '$year' : '$year-$month';
    return '${BtrBangumiApi.siteBaseUrl}/anime/browser/airtime/$airtime?$query';
  }

  @override
  Widget build(BuildContext context) {
    var result = ref.watch(bangumiRankingProvider(_query));
    var totalPages = result.asData?.value.data?.totalPages ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(loading: result.isLoading, totalPages: totalPages),
        Expanded(
          child: result.when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            data: _buildResult,
            loading: () => BTEmptyState.loading(message: '正在加载排行榜...'),
            error: (_, _) =>
                BTEmptyState.error(message: '排行榜加载失败，请重试', onAction: _refresh),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({required bool loading, required int totalPages}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BTIconToggleGroup<BangumiSubjectBrowseSort>(
                value: _sort,
                options: [
                  for (var sort in BangumiSubjectBrowseSort.values)
                    BTIconToggleOption(
                      value: sort,
                      label: sort.label,
                      icon: sort.icon,
                    ),
                ],
                onChanged: widget.onSortChanged,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildPagination(loading: loading, totalPages: totalPages),
                    Tooltip(
                      message: loading ? '正在刷新排行榜' : '刷新排行榜',
                      child: IconButton(
                        onPressed: loading ? null : _refresh,
                        icon: loading
                            ? const SizedBox.square(
                                dimension: 14,
                                child: ProgressRing(strokeWidth: 2),
                              )
                            : const Icon(
                                FluentIcons.refresh,
                                size: 14,
                                semanticLabel: '刷新排行榜',
                              ),
                      ),
                    ),
                    Tooltip(
                      message: '在浏览器中打开榜单',
                      child: IconButton(
                        icon: const Icon(
                          FluentIcons.open_in_new_window,
                          size: 14,
                          semanticLabel: '在浏览器中打开榜单',
                        ),
                        onPressed: () async {
                          await launchUrlString(_browserUrl);
                        },
                      ),
                    ),
                    Tooltip(
                      message: '搜索',
                      child: IconButton(
                        icon: const Icon(
                          FluentIcons.search,
                          size: 14,
                          semanticLabel: '搜索',
                        ),
                        onPressed: () => SubjectSearchPage.open(ref),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('时间', style: BTTypography.caption(context)),
              const SizedBox(width: 8),
              BangumiRankingTimeFilter(value: _time, onChanged: _changeTime),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${_sort.description} · 每页 24 部',
                  style: BTTypography.caption(context),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPagination({required bool loading, required int totalPages}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: '上一页',
          child: IconButton(
            icon: const Icon(
              FluentIcons.chevron_left,
              size: 14,
              semanticLabel: '上一页',
            ),
            onPressed: !loading && _page > 1
                ? () => setState(() => _pages[_sort] = _page - 1)
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            totalPages > 0 ? '$_page / $totalPages 页' : '第 $_page 页',
            style: BTTypography.caption(context),
          ),
        ),
        Tooltip(
          message: '下一页',
          child: IconButton(
            icon: const Icon(
              FluentIcons.chevron_right,
              size: 14,
              semanticLabel: '下一页',
            ),
            onPressed: !loading && _page < totalPages
                ? () => setState(() => _pages[_sort] = _page + 1)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildResult(BTResponse<BangumiSubjectBrowsePage> response) {
    var data = response.data;
    if (response.code != 0 || data == null) {
      return BTEmptyState.error(
        title: '排行榜加载失败',
        message: AppError.fromResponse(response).displayMessage,
        onAction: _refresh,
      );
    }
    // 与首页日历一致，即使登录账号有权限也不展示成人向条目。
    var items = data.items.indexed
        .where((entry) => !entry.$2.subject.nsfw)
        .toList();
    if (items.isEmpty) {
      var hasTime = _time.isActive;
      return BTEmptyState.noData(
        title: '暂无可显示的榜单条目',
        message: hasTime ? '可调整时间筛选、切换榜单或稍后刷新' : '可切换榜单、翻页或稍后刷新',
        actionText: hasTime ? '清除时间筛选' : '刷新',
        onAction: hasTime
            ? () => _changeTime(BangumiSubjectBrowseTime.all)
            : _refresh,
      );
    }
    return ListView.separated(
      key: ValueKey((_sort, _page, _time.year, _time.month)),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        var (sourceIndex, item) = items[index];
        return BangumiRankingCard(
          key: ValueKey(item.subject.id),
          item: item,
          position:
              (_page - 1) * BangumiSubjectBrowsePage.pageSize + sourceIndex + 1,
        );
      },
    );
  }
}
