// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../controller/app/progress_controller.dart';
import '../../database/app/app_bmf.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/hive/nav_model.dart';
import '../../plugins/mikan/mikan_api.dart';
import '../../plugins/mikan/models/mikan_model.dart';
import '../../providers/app_providers.dart';
import '../../store/bgm_user_hive.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../utils/tool_func.dart';
import '../../core/theme/bt_theme.dart';
import '../../widgets/common/bt_animations.dart';
import '../../widgets/common/bt_drawer.dart';
import '../../widgets/bangumi/subject_detail/bsd_bmf_drawer.dart';
import '../../widgets/bangumi/subject_detail/bsd_user_collection.dart';
import '../../widgets/bangumi/subject_detail/bsd_user_episodes.dart';
import 'sd_pw_overview.dart';
import 'sd_pw_relation.dart';

/// 监听收藏状态变更
class SubjectCollectStatProvider extends StateNotifier<bool> {
  /// 构造函数
  SubjectCollectStatProvider() : super(false);

  /// set
  void set(bool value) => state = value;
}

/// 监听Rss变更
class SubjectRssStatProvider extends StateNotifier<String?> {
  /// 构造函数
  SubjectRssStatProvider() : super(null);

  /// set
  void set(String value) => state = value;
}

/// 番剧详情
/// TODO: 页面UI重构
class SubjectDetailPage extends ConsumerStatefulWidget {
  /// 番剧 id
  final String id;

  /// 构造函数
  const SubjectDetailPage({super.key, required this.id});

  @override
  ConsumerState<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

/// 番剧详情状态
class _SubjectDetailPageState extends ConsumerState<SubjectDetailPage>
    with AutomaticKeepAliveClientMixin {
  /// 番剧数据
  BangumiSubject? data;

  /// 用户Hive
  final BgmUserHive hiveUser = BgmUserHive();

  /// mikanApi
  final BtrMikanApi mikanApi = BtrMikanApi();

  /// bmf数据库
  final BtsAppBmf sqliteBmf = BtsAppBmf();

  /// collect provider
  final SubjectCollectStatProvider collectProvider =
      SubjectCollectStatProvider();

  /// rss provider
  final SubjectRssStatProvider rssProvider = SubjectRssStatProvider();

  /// progress
  late ProgressController progress = ProgressController();

  @override
  bool get wantKeepAlive => true;

  /// 是否显示错误组件
  bool showError = false;

  /// 当id改变时, 重新加载数据
  @override
  void didUpdateWidget(SubjectDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      data = null;
      Future.microtask(init);
    }
  }

  /// 构建函数
  @override
  void initState() {
    super.initState();
    Future.microtask(init);
  }

  Future<void> init() async {
    if (showError) setState(() => showError = false);
    setState(() => data = null);
    var repository = ref.read(bangumiRepositoryProvider);
    var detailGet = await repository.getSubjectDetail(widget.id);
    if (detailGet.code != 0 || detailGet.data == null) {
      if (mounted) await showRespErr(detailGet, context);
      showError = true;
      return;
    }
    setState(() => data = detailGet.data);
  }

  Future<void> searchBangumi() async {
    if (data == null) {
      await BtInfobar.error(context, '数据为空');
      return;
    }
    var name = data?.nameCn == '' ? data?.name : data?.nameCn;
    if (name == null) {
      await BtInfobar.error(context, '数据为空');
      return;
    }
    var nameCheck = await showInput(
      context,
      title: '搜索番剧',
      content: '请输入番剧名称',
      value: name,
    );
    if (nameCheck == null) return;
    if (mounted) {
      progress = ProgressWidget.show(
        context,
        title: '搜索中',
        text: '正在搜索番剧: $nameCheck',
        progress: null,
      );
    }
    var resp = await mikanApi.searchBgm(nameCheck);
    progress.end();
    if (resp.code != 0) {
      if (mounted) await showRespErr(resp, context);
      return;
    }
    var items = resp.data as List<MikanSearchItemModel>;
    if (items.isEmpty) {
      if (mounted) await BtInfobar.error(context, '没有找到相关条目，请尝试更换搜索词');
      return;
    }
    if (mounted) await showSearchResult(context, items);
  }

  /// 显示搜索结果
  Future<void> showSearchResult(
    BuildContext context,
    List<MikanSearchItemModel> items,
  ) async {
    var result = await showDialog(
      context: context,
      barrierDismissible: true,
      dismissWithEsc: true,
      builder: (context) {
        return ContentDialog(
          title: const Text('搜索结果'),
          content: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              var item = items[index];
              return ListTile(
                title: Text(item.title),
                subtitle: Text(item.link),
                onPressed: () async {
                  var confirm = await showConfirm(
                    context,
                    title: '确认匹配？',
                    content: '将该结果设为BMF的RSS',
                  );
                  if (!confirm) return;
                  rssProvider.set(item.rss);
                  if (context.mounted) {
                    await BtInfobar.success(context, '成功设置RSS');
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
              );
            },
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
    if (result == null) return;
  }

  /// 构建顶部栏
  Widget buildHeader() {
    String? title;
    if (data == null) {
      title = 'ID: ${widget.id}';
    } else {
      title = data?.nameCn == '' ? data?.name : data?.nameCn;
    }
    return PageHeader(
      leading: IconButton(
        icon: const Icon(FluentIcons.back),
        onPressed: () {
          if (data == null) {
            BtInfobar.error(context, '数据为空');
            return;
          }
          ref
              .read(navStoreProvider)
              .removeNavItem(
                '${data!.type.label}详情 ${widget.id}',
                type: BtmAppNavItemType.subject,
                param: 'subjectDetail_${widget.id}',
              );
        },
      ),
      title: Tooltip(
        message: title,
        child: Text(
          '${data?.type.label ?? '条目'}详情：$title',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      commandBar: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: '复制标题',
            child: IconButton(
              icon: const Icon(FluentIcons.copy),
              onPressed: () {
                if (title == null) {
                  BtInfobar.error(context, '标题为空');
                  return;
                }
                Clipboard.setData(ClipboardData(text: title));
                BtInfobar.success(context, '已复制标题: $title');
              },
            ),
          ),
          Tooltip(
            message: '刷新页面',
            child: IconButton(
              icon: const Icon(FluentIcons.refresh),
              onPressed: init,
            ),
          ),
          Tooltip(
            message: '搜索RSS(Mikan)',
            child: IconButton(
              icon: const Icon(FluentIcons.search),
              onPressed: searchBangumi,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建加载中
  Widget buildLoading() {
    if (showError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(FluentIcons.error),
            SizedBox(height: 12.h),
            const Text('Error: 加载失败'),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ProgressRing(),
          SizedBox(height: 12.h),
          const Text('Loading...'),
        ],
      ),
    );
  }

  Widget _buildBmfDrawerButton(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;
    return Tooltip(
      message: '打开 BMF 配置',
      excludeFromSemantics: true,
      child: IconButton(
        icon: Icon(
          FluentIcons.app_icon_default,
          size: 18.sp,
          color: accentColor,
        ),
        onPressed: () => showBTDrawer(
          context: context,
          width: 420,
          child: BsdBmfDrawer(
            subjectId: data!.id,
            title: data!.nameCn.isEmpty ? data!.name : data!.nameCn,
            rssProvider: rssProvider,
          ),
        ),
      ),
    );
  }

  Widget buildContextMenu(BuildContext context, EditableTextState state) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    var backgroundColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    var textColor = isDark ? Colors.white : Colors.black;

    return CustomSingleChildLayout(
      delegate: TextSelectionToolbarLayoutDelegate(
        anchorAbove: state.contextMenuAnchors.primaryAnchor,
        anchorBelow:
            state.contextMenuAnchors.secondaryAnchor ??
            state.contextMenuAnchors.primaryAnchor,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: state.contextMenuButtonItems.map((item) {
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: item.onPressed,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    item.label ?? '',
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget buildSummary(String summary) {
    if (summary == '') {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            Icon(
              FluentIcons.error_badge,
              size: 16.sp,
              color: BTColors.textTertiary(context),
            ),
            SizedBox(width: 8.w),
            Text('暂无简介', style: BTTypography.body(context)),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: SelectableText(
        summary,
        style: BTTypography.body(context),
        contextMenuBuilder: buildContextMenu,
      ),
    );
  }

  Widget buildOtherInfo(List<BangumiInfoBoxItem> infobox) {
    if (infobox.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            Icon(
              FluentIcons.info,
              size: 16.sp,
              color: BTColors.textTertiary(context),
            ),
            SizedBox(width: 8.w),
            Text('暂无其他信息', style: BTTypography.body(context)),
          ],
        ),
      );
    }
    var res = <Widget>[];
    for (var item in infobox) {
      String value;
      if (item.value is List) {
        var list = item.value as List;
        value = list
            .map((e) => e['k'] != null ? '${e['k']}: ${e['v']}' : e['v'])
            .toList()
            .map((e) => replaceEscape(e as String))
            .join('\n');
        res.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.key, style: BTTypography.bodyStrong(context)),
                SizedBox(height: 2.h),
                SelectableText(
                  value,
                  style: BTTypography.body(context),
                  contextMenuBuilder: buildContextMenu,
                ),
              ],
            ),
          ),
        );
      } else {
        value = replaceEscape(item.value as String);
        res.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80.w,
                  child: Text(
                    item.key,
                    style: BTTypography.bodyStrong(context),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: SelectableText(
                    value,
                    style: BTTypography.body(context),
                    contextMenuBuilder: buildContextMenu,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: res,
    );
  }

  Widget buildContent() {
    if (data == null) return buildLoading();
    assert(data != null);
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BTFadeSlideIn(
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: isDark
                    ? BTColors.surfaceSecondary(context)
                    : BTColors.surfacePrimary(context),
                borderRadius: BTRadius.largeBR,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04),
                ),
                boxShadow: BTTheme.shadow(context, level: BTShadowLevel.medium),
              ),
              child: SdpOverviewWidget(data!),
            ),
          ),
          SizedBox(height: 12.h),

          if (hiveUser.user != null)
            BTFadeSlideIn(
              duration: const Duration(milliseconds: 350),
              delay: const Duration(milliseconds: 50),
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: BTColors.surfaceSecondary(context),
                  borderRadius: BTRadius.mediumBR,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: BsdUserCollection(
                        data!,
                        hiveUser.user!,
                        collectProvider,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    _buildBmfDrawerButton(context),
                  ],
                ),
              ),
            ),

          BTFadeSlideIn(
            duration: const Duration(milliseconds: 400),
            delay: const Duration(milliseconds: 100),
            child: Expander(
              initiallyExpanded: true,
              leading: Icon(
                FluentIcons.video,
                size: 18.sp,
                color: FluentTheme.of(context).accentColor,
              ),
              header: Text('剧集列表', style: BTTypography.subtitle(context)),
              content: BsdUserEpisodes(data!, hiveUser.user, collectProvider),
            ),
          ),

          BTFadeSlideIn(
            duration: const Duration(milliseconds: 450),
            delay: const Duration(milliseconds: 150),
            child: Expander(
              leading: Icon(
                FluentIcons.link,
                size: 18.sp,
                color: FluentTheme.of(context).accentColor,
              ),
              header: Text('关联条目', style: BTTypography.subtitle(context)),
              content: SdpRelationWidget(data!.id),
            ),
          ),

          BTFadeSlideIn(
            duration: const Duration(milliseconds: 500),
            delay: const Duration(milliseconds: 200),
            child: Expander(
              initiallyExpanded: true,
              leading: Icon(
                FluentIcons.info,
                size: 18.sp,
                color: FluentTheme.of(context).accentColor,
              ),
              header: Text('简介', style: BTTypography.subtitle(context)),
              content: buildSummary(data!.summary),
            ),
          ),

          BTFadeSlideIn(
            duration: const Duration(milliseconds: 550),
            delay: const Duration(milliseconds: 250),
            child: Expander(
              leading: Icon(
                FluentIcons.settings,
                size: 18.sp,
                color: FluentTheme.of(context).accentColor,
              ),
              header: Text('详细信息', style: BTTypography.subtitle(context)),
              content: buildOtherInfo(data!.infobox),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(header: buildHeader(), content: buildContent());
  }
}
