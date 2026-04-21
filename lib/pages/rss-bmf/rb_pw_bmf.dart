import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/bt_theme.dart';
import '../../database/app/app_rss.dart';
import '../../models/database/app_bmf_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/bt_icon.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/bangumi/subject_detail/bmf_card.dart';

class BmfFilterStats {
  final int total;
  final int hasRss;
  final int hasDownload;

  const BmfFilterStats({
    required this.total,
    required this.hasRss,
    required this.hasDownload,
  });

  static const empty = BmfFilterStats(total: 0, hasRss: 0, hasDownload: 0);
}

class RbpBmfWidget extends ConsumerStatefulWidget {
  const RbpBmfWidget({super.key});

  @override
  ConsumerState<RbpBmfWidget> createState() => _RbpBmfState();
}

class _RbpBmfState extends ConsumerState<RbpBmfWidget>
    with AutomaticKeepAliveClientMixin {
  final BtsAppRss rss = BtsAppRss();

  List<AppBmfModel> filteredList = [];
  BmfFilterStats filterStats = BmfFilterStats.empty;
  String searchQuery = '';
  bool showAll = true;
  bool filterHasRss = true;
  bool filterHasDownload = true;

  Timer? _debounceTimer;
  bool _preCheckDone = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _preCheck(List<AppBmfModel> bmfList) async {
    if (_preCheckDone || bmfList.isEmpty) return;
    _preCheckDone = true;

    var rssList = await rss.readAll();
    var usedMkIds = bmfList
        .where((item) => item.mkBgmId != null && item.mkBgmId!.isNotEmpty)
        .map((item) => item.mkBgmId)
        .toSet();

    var unusedRss = rssList.where((rssItem) {
      if (rssItem.mkBgmId == null || rssItem.mkBgmId!.isEmpty) return false;
      return !usedMkIds.contains(rssItem.mkBgmId);
    }).toList();

    var cnt = unusedRss.length;
    for (var item in unusedRss) {
      await rss.deleteByMkId(item.mkBgmId!);
    }
    if (cnt > 0 && mounted) {
      await BtInfobar.warn(context, '删除了 $cnt 条未使用的RSS');
    }
  }

  void _computeStats(List<AppBmfModel> bmfList) {
    int hasRss = 0;
    int hasDownload = 0;
    for (var bmf in bmfList) {
      if (bmf.rss != null && bmf.rss!.isNotEmpty) hasRss++;
      if (bmf.download != null && bmf.download!.isNotEmpty) hasDownload++;
    }
    filterStats = BmfFilterStats(
      total: bmfList.length,
      hasRss: hasRss,
      hasDownload: hasDownload,
    );
  }

  void applyFilter(List<AppBmfModel> bmfList) {
    _computeStats(bmfList);

    filteredList = bmfList.where((bmf) {
      var matchesSearch =
          searchQuery.isEmpty ||
          (bmf.title?.toLowerCase().contains(searchQuery.toLowerCase()) ??
              false) ||
          bmf.subject.toString().contains(searchQuery);

      if (showAll) return matchesSearch;

      var hasRss = bmf.rss != null && bmf.rss!.isNotEmpty;
      var hasDownload = bmf.download != null && bmf.download!.isNotEmpty;

      var matchesRss = filterHasRss ? hasRss : !hasRss;
      var matchesDownload = filterHasDownload ? hasDownload : !hasDownload;

      return matchesSearch && matchesRss && matchesDownload;
    }).toList();
  }

  void onSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          searchQuery = query;
        });
      }
    });
  }

  Future<void> deleteBmf(AppBmfModel bmf) async {
    var repo = ref.read(bmfRepositoryProvider);
    await repo.delete(bmf.subject);
    if (mounted) await BtInfobar.success(context, '成功删除 BMF 信息');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var bmfListAsync = ref.watch(bmfListProvider);

    ref.listen<AsyncValue<List<AppBmfModel>>>(bmfListProvider, (prev, next) {
      next.whenData((bmfList) {
        if (!_preCheckDone) {
          _preCheck(bmfList);
        }
      });
    });

    return bmfListAsync.when(
      data: (bmfList) {
        applyFilter(bmfList);
        return ScaffoldPage(
          padding: EdgeInsets.zero,
          header: _buildHeader(context),
          content: _buildContent(context),
        );
      },
      loading: () => ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Center(child: ProgressRing()),
      ),
      error: (error, stack) => ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Center(child: Text('加载失败: $error')),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/images/logo.png', height: 24, width: 24),
              SizedBox(width: 8.w),
              Text('BMF配置', style: BTTypography.title(context)),
              SizedBox(width: 12.w),
              Tooltip(
                message: '刷新',
                child: IconButton(
                  icon: BtIcon(FluentIcons.refresh),
                  onPressed: () async {
                    await ref.read(bmfListProvider.notifier).refresh();
                    if (context.mounted) {
                      await BtInfobar.success(context, 'BMF 配置刷新完成');
                    }
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(child: _buildFilterChips(context)),
              SizedBox(width: 16.w),
              SizedBox(
                width: 240.w,
                child: TextBox(
                  placeholder: '搜索标题或ID...',
                  prefix: BtIcon(FluentIcons.search, size: 14.sp),
                  onChanged: onSearch,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return Row(
      children: [
        _buildFilterChip(
          context,
          label: '全部',
          count: filterStats.total,
          isSelected: showAll,
          onTap: () => setState(() {
            showAll = true;
            filterHasRss = true;
            filterHasDownload = true;
          }),
        ),
        SizedBox(width: 16.w),
        _buildFilterCheckbox(
          context,
          label: '有RSS',
          count: filterStats.hasRss,
          value: filterHasRss,
          onChanged: (val) => setState(() {
            showAll = false;
            filterHasRss = val;
          }),
        ),
        SizedBox(width: 16.w),
        _buildFilterCheckbox(
          context,
          label: '有下载目录',
          count: filterStats.hasDownload,
          value: filterHasDownload,
          onChanged: (val) => setState(() {
            showAll = false;
            filterHasDownload = val;
          }),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    var accentColor = FluentTheme.of(context).accentColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: BTDurations.fadeTransition,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : BTColors.surfaceSecondary(context),
          borderRadius: BTRadius.mediumBR,
          border: Border.all(
            color: isSelected ? accentColor : BTColors.divider(context),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: BTTypography.body(context).copyWith(
                color: isSelected ? accentColor : BTColors.textPrimary(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.2)
                    : BTColors.surfaceTertiary(context),
                borderRadius: BTRadius.smallBR,
              ),
              child: Text(
                '$count',
                style: BTTypography.caption(context).copyWith(
                  color: isSelected
                      ? accentColor
                      : BTColors.textSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCheckbox(
    BuildContext context, {
    required String label,
    required int count,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    var accentColor = FluentTheme.of(context).accentColor;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: BTDurations.fadeTransition,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: value
              ? accentColor.withValues(alpha: 0.15)
              : BTColors.surfaceSecondary(context),
          borderRadius: BTRadius.mediumBR,
          border: Border.all(
            color: value ? accentColor : BTColors.divider(context),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? FluentIcons.checkbox_composite : FluentIcons.checkbox,
              size: 16.sp,
              color: value ? accentColor : BTColors.textSecondary(context),
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: BTTypography.body(context).copyWith(
                color: value ? accentColor : BTColors.textPrimary(context),
                fontWeight: value ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: value
                    ? accentColor.withValues(alpha: 0.2)
                    : BTColors.surfaceTertiary(context),
                borderRadius: BTRadius.smallBR,
              ),
              child: Text(
                '$count',
                style: BTTypography.caption(context).copyWith(
                  color: value
                      ? accentColor
                      : BTColors.textSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (filteredList.isEmpty) {
      return _buildEmptyState(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        var crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
        var spacing = 12.w;
        var horizontalPadding = 16.w;
        var availableWidth =
            constraints.maxWidth -
            horizontalPadding * 2 -
            (crossAxisCount - 1) * spacing;
        var itemWidth = availableWidth / crossAxisCount;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            8.h,
            horizontalPadding,
            16.h,
          ),
          child: Wrap(
            spacing: spacing,
            runSpacing: 12.h,
            children: filteredList
                .map(
                  (bmf) => SizedBox(
                    width: itemWidth,
                    child: BmfCard(bmf: bmf, onDelete: () => deleteBmf(bmf)),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  int _getCrossAxisCount(double width) {
    if (width < 500) return 1;
    if (width < 750) return 2;
    if (width < 1000) return 3;
    if (width < 1300) return 4;
    return 5;
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.info,
            size: 48.sp,
            color: BTColors.textTertiary(context),
          ),
          SizedBox(height: 16.h),
          Text(
            searchQuery.isNotEmpty ? '没有找到匹配的配置' : '暂无 BMF 配置',
            style: BTTypography.subtitle(
              context,
            ).copyWith(color: BTColors.textSecondary(context)),
          ),
          SizedBox(height: 8.h),
          Text(
            searchQuery.isNotEmpty ? '尝试其他搜索关键词' : '请在动画详情页添加 BMF 配置',
            style: BTTypography.caption(context),
          ),
        ],
      ),
    );
  }
}
