import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/bt_theme.dart';
import '../../database/app/app_bmf.dart';
import '../../database/app/app_rss.dart';
import '../../models/database/app_bmf_model.dart';
import '../../ui/bt_icon.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/bangumi/subject_detail/bmf_card.dart';

class RbpBmfWidget extends StatefulWidget {
  const RbpBmfWidget({super.key});

  @override
  State<RbpBmfWidget> createState() => _RbpBmfState();
}

class _RbpBmfState extends State<RbpBmfWidget>
    with AutomaticKeepAliveClientMixin {
  final BtsAppBmf sqlite = BtsAppBmf();
  final BtsAppRss rss = BtsAppRss();

  List<AppBmfModel> bmfList = [];
  List<AppBmfModel> filteredList = [];
  String searchQuery = '';
  BmfFilterType currentFilter = BmfFilterType.all;
  bool isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await preCheck();
      await init();
    });
  }

  Future<void> preCheck() async {
    var read = await sqlite.readAll();
    var rssList = await rss.readAll();
    for (var item in read) {
      if (item.rss != null && item.rss!.isNotEmpty) {
        rssList.removeWhere((e) => e.mkBgmId == item.mkBgmId);
      }
    }
    var cnt = rssList.length;
    for (var item in rssList) {
      if (item.mkBgmId != null) await rss.deleteByMkId(item.mkBgmId!);
    }
    if (cnt > 0 && mounted) {
      await BtInfobar.warn(context, '删除了 $cnt 条未使用的RSS');
    }
  }

  Future<void> init() async {
    setState(() => isLoading = true);
    bmfList = await sqlite.readAll();
    applyFilter();
    setState(() => isLoading = false);
    if (mounted) await BtInfobar.success(context, '成功加载BMF配置');
  }

  void applyFilter() {
    filteredList = bmfList.where((bmf) {
      var matchesSearch = searchQuery.isEmpty ||
          (bmf.title?.toLowerCase().contains(searchQuery.toLowerCase()) ??
              false) ||
          bmf.subject.toString().contains(searchQuery);

      var matchesFilter = switch (currentFilter) {
        BmfFilterType.all => true,
        BmfFilterType.hasRss => bmf.rss != null && bmf.rss!.isNotEmpty,
        BmfFilterType.hasDownload =>
          bmf.download != null && bmf.download!.isNotEmpty,
        BmfFilterType.hasNew => false,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  void onSearch(String query) {
    searchQuery = query;
    applyFilter();
    setState(() {});
  }

  void onFilterChanged(BmfFilterType filter) {
    currentFilter = filter;
    applyFilter();
    setState(() {});
  }

  Future<void> deleteBmf(AppBmfModel bmf) async {
    await sqlite.delete(bmf.subject);
    if (bmf.rss != null && bmf.rss!.isNotEmpty) {
      await rss.delete(bmf.rss!);
    }
    bmfList.removeWhere((e) => e.subject == bmf.subject);
    applyFilter();
    setState(() {});
    if (mounted) await BtInfobar.success(context, '成功删除 BMF 信息');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      header: _buildHeader(context),
      content: _buildContent(context),
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
                  onPressed: init,
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
          count: bmfList.length,
          filter: BmfFilterType.all,
        ),
        SizedBox(width: 8.w),
        _buildFilterChip(
          context,
          label: '有RSS',
          count: bmfList
              .where((b) => b.rss != null && b.rss!.isNotEmpty)
              .length,
          filter: BmfFilterType.hasRss,
        ),
        SizedBox(width: 8.w),
        _buildFilterChip(
          context,
          label: '有下载目录',
          count: bmfList
              .where((b) => b.download != null && b.download!.isNotEmpty)
              .length,
          filter: BmfFilterType.hasDownload,
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required int count,
    required BmfFilterType filter,
  }) {
    var isSelected = currentFilter == filter;
    var accentColor = FluentTheme.of(context).accentColor;

    return GestureDetector(
      onTap: () => onFilterChanged(filter),
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

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return Center(child: ProgressRing());
    }

    if (filteredList.isEmpty) {
      return _buildEmptyState(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        var crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
        var spacing = 12.w;
        var horizontalPadding = 16.w;
        var availableWidth = constraints.maxWidth -
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
                .map((bmf) => SizedBox(
                      width: itemWidth,
                      child: BmfCard(
                        bmf: bmf,
                        onUpdate: init,
                        onDelete: () => deleteBmf(bmf),
                      ),
                    ))
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
            style: BTTypography.subtitle(context).copyWith(
              color: BTColors.textSecondary(context),
            ),
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
