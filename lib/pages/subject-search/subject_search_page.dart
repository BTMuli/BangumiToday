// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../controller/app/page_controller.dart';
import '../../core/theme/bt_theme.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_subject.dart';
import '../../providers/app_providers.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/bangumi/subject_card/bsc_search.dart';
import '../../widgets/common/bt_animations.dart';
import '../../widgets/common/bt_card.dart';
import '../../widgets/common/empty_state.dart';

/// 搜索页面
class SubjectSearchPage extends ConsumerStatefulWidget {
  /// 构造函数
  const SubjectSearchPage({super.key});

  @override
  ConsumerState<SubjectSearchPage> createState() => _SubjectSearchPageState();
}

/// 搜索页面状态
class _SubjectSearchPageState extends ConsumerState<SubjectSearchPage>
    with AutomaticKeepAliveClientMixin {
  /// controller
  late BtcPageController controller = BtcPageController.defaultInit();

  /// offset
  int offset = 0;

  /// 每页限制
  /// todo 后续可以根据屏幕大小动态调整
  final int limit = 12;

  /// text controller
  final TextEditingController textController = TextEditingController();

  /// 排序方式-label对照
  final sortMap = {'match': '匹配度', 'heat': '收藏人数', 'rank': '排名', 'score': '评分'};

  /// 当前排序方式
  String sort = 'match';

  /// 当前搜索类型
  List<BangumiSubjectType> types = [BangumiSubjectType.anime];

  /// 是否显示NSFW
  bool? nsfw = false;

  /// nsfwList
  List nsfwList = [true, false, null];

  /// 搜索结果
  Map<String, List<BangumiSubjectSearchData>> resultMap = {};

  /// 搜索结果
  List<BangumiSubjectSearchData> result = [];

  /// 总结果数
  int totalResults = 0;

  /// 是否在加载中
  bool loading = false;

  /// 视图模式：true为网格视图，false为列表视图
  bool isGridView = false;

  /// 保持状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化函数
  @override
  void initState() {
    super.initState();
    controller.onChanged = onPageChanged;
  }

  /// dispose
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// 页面改变
  Future<void> onPageChanged(int page) async {
    if (resultMap.containsKey('page_$page')) {
      setState(() => result = resultMap['page_$page']!);
      return;
    }
    setState(() => loading = true);
    var repository = ref.read(bangumiRepositoryProvider);
    var resp = await repository.searchSubjects(
      textController.text,
      sort: sort,
      type: types,
      nsfw: nsfw,
      offset: (page - 1) * limit,
      limit: limit,
    );
    if (!mounted) return;
    if (resp.code != 0 || resp.data == null) {
      setState(() => loading = false);
      await showRespErr(resp, context);
      return;
    }
    var data = resp.data as BangumiPageT<BangumiSubjectSearchData>;
    resultMap['page_$page'] = data.data;
    result = data.data;
    loading = false;
    setState(() {});
  }

  /// 搜索
  Future<void> search() async {
    var input = textController.text;
    if (input.isEmpty) {
      offset = 0;
      controller.reset(total: 0, cur: 0);
      result.clear();
      resultMap.clear();
      setState(() {});
      await BtInfobar.warn(context, '请输入搜索内容');
      return;
    }
    if (types.isEmpty) {
      await BtInfobar.warn(context, '请至少选择一个搜索类型');
      return;
    }
    if (loading) return;
    loading = true;
    result.clear();
    resultMap.clear();
    setState(() {});
    if (result.isNotEmpty) {
      loading = false;
      await controller.jump(1);
      setState(() {});
      return;
    }
    var repository = ref.read(bangumiRepositoryProvider);
    var resp = await repository.searchSubjects(
      input,
      sort: sort,
      type: types,
      nsfw: nsfw,
      offset: offset,
      limit: limit,
    );
    if (!mounted) return;
    if (resp.code != 0 || resp.data == null) {
      setState(() => loading = false);
      await showRespErr(resp, context);
      return;
    }
    var data = resp.data as BangumiPageT<BangumiSubjectSearchData>;
    if (data.total == 0) {
      if (mounted) await BtInfobar.warn(context, '没有找到相关条目');
      loading = false;
      setState(() {});
      return;
    }
    result = data.data;
    resultMap['page_1'] = data.data;
    totalResults = data.total;
    var totalPage = (data.total / limit).ceil();
    controller.reset(total: totalPage, cur: 1);
    loading = false;
    setState(() {});
  }

  /// 构建头部
  Widget buildHeader(BuildContext context) {
    return PageHeader(
      leading: IconButton(
        icon: const Icon(FluentIcons.back),
        onPressed: () {
          ref.read(navStoreProvider).removeNavItem('Bangumi-条目搜索');
        },
      ),
      title: const Text('Bangumi-条目搜索'),
    );
  }

  /// 根据排序方式获取对应MenuFlyoutItem
  MenuFlyoutItem buildSortItem(String key) {
    if (!sortMap.containsKey(key)) throw '未知排序方式';
    IconData icon;
    switch (key) {
      case 'match':
        icon = FluentIcons.default_settings;
        break;
      case 'heat':
        icon = FluentIcons.heart_fill;
        break;
      case 'rank':
        icon = FluentIcons.bar_chart4;
        break;
      case 'score':
        icon = FluentIcons.number_field;
        break;
      default:
        icon = FluentIcons.info;
    }
    return MenuFlyoutItem(
      text: Text(sortMap[key]!),
      selected: sort == key,
      trailing: sort == key ? const Icon(FluentIcons.check_mark) : null,
      leading: Icon(icon, color: FluentTheme.of(context).accentColor),
      onPressed: () {
        sort = key;
        setState(() {});
      },
    );
  }

  /// 构建排序方式选择
  /// bug: 该属性的变化无法影响搜索结果
  /// 详见：https://github.com/bangumi/server/issues/532
  Widget buildSortSelect() {
    var label = sortMap[sort] ?? '未知';
    return DropDownButton(
      title: Text('排序方式: $label'),
      items: sortMap.keys.map(buildSortItem).toList(),
    );
  }

  Widget buildTypeSelects() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: BangumiSubjectType.values.map((type) {
        return Padding(
          padding: EdgeInsets.only(right: 8),
          child: _FilterChip(
            label: type.label,
            isSelected: types.contains(type),
            onTap: () {
              setState(() {
                if (types.contains(type)) {
                  types.remove(type);
                } else {
                  types.add(type);
                }
              });
            },
          ),
        );
      }).toList(),
    );
  }

  Widget buildNsfwCheck() {
    var nsfwLabel = nsfw == true ? '包含' : (nsfw == false ? '排除' : '全部');
    return _FilterChip(
      label: 'NSFW: $nsfwLabel',
      isSelected: nsfw != false,
      onTap: () {
        var index = nsfwList.indexOf(nsfw);
        if (index == -1) {
          BtInfobar.error(context, '未知值');
          return;
        }
        setState(() {
          nsfw = nsfwList[(index + 1) % nsfwList.length];
        });
      },
    );
  }

  Widget buildSearch() {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BTRadius.largeBR,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _AnimatedSearchButton(
                onPressed: () async => await search(),
                isLoading: loading,
              ),
              SizedBox(width: 12),
              Expanded(
                child: _AnimatedSearchBox(
                  controller: textController,
                  onSubmitted: (_) async => await search(),
                  onClear: () {
                    textController.clear();
                    setState(() {});
                  },
                ),
              ),
              SizedBox(width: 12),
              buildTypeSelects(),
              SizedBox(width: 8),
              buildNsfwCheck(),
            ],
          ),
          if (types.isNotEmpty) ...[
            SizedBox(height: 12),
            _buildSelectedTypeChips(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedTypeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((type) {
        return _FilterChip(
          label: type.label,
          isSelected: true,
          onDeleted: () {
            setState(() {
              types.remove(type);
            });
          },
        );
      }).toList(),
    );
  }

  Widget buildResult() {
    if (loading) {
      return BTEmptyState.loading(message: '正在搜索...');
    }
    if (controller.total == 0) {
      return BTEmptyState.noSearchResult(
        keyword: textController.text.isEmpty ? null : textController.text,
        actionText: '清除搜索',
        onAction: () {
          textController.clear();
          setState(() {});
        },
      );
    }
    return Column(
      children: [
        _buildViewToggle(),
        Expanded(child: isGridView ? _buildGridView() : _buildListView()),
      ],
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (totalResults > 0)
            Row(
              children: [
                Icon(
                  FluentIcons.search,
                  size: 14,
                  color: BTColors.textSecondary(context),
                ),
                SizedBox(width: 6),
                Text(
                  '找到 $totalResults 个结果',
                  style: TextStyle(
                    fontSize: 13,
                    color: BTColors.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: FluentTheme.of(
                      context,
                    ).accentColor.withValues(alpha: 0.1),
                    borderRadius: BTRadius.smallBR,
                  ),
                  child: Text(
                    '第 ${controller.cur}/${controller.total} 页',
                    style: TextStyle(
                      fontSize: 12,
                      color: FluentTheme.of(context).accentColor,
                    ),
                  ),
                ),
              ],
            ),
          const Spacer(),
          Tooltip(
            message: isGridView ? '切换到列表视图' : '切换到网格视图',
            child: BTCard(
              useShadow: false,
              useAcrylic: true,
              acrylicOpacity: 0.7,
              padding: EdgeInsets.all(4),
              borderRadius: BTRadius.small,
              onTap: () {
                setState(() {
                  isGridView = !isGridView;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGridView ? FluentIcons.list : FluentIcons.tiles,
                    size: 14,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  SizedBox(width: 6),
                  Text(
                    isGridView ? '列表' : '网格',
                    style: TextStyle(
                      fontSize: 12,
                      color: BTColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: result.length,
      itemBuilder: (context, index) {
        return BTFadeSlideIn(
          duration: const Duration(milliseconds: 300),
          delay: Duration(milliseconds: index * 50),
          offset: const Offset(0, 0.05),
          child: BscSearch(result[index]),
        );
      },
      separatorBuilder: (context, index) => SizedBox(height: 12),
    );
  }

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        var crossAxisCount = _calculateCrossAxisCount(constraints.maxWidth);
        return GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.65,
          ),
          itemCount: result.length,
          itemBuilder: (context, index) {
            return BTFadeSlideIn(
              duration: const Duration(milliseconds: 300),
              delay: Duration(milliseconds: index * 50),
              offset: const Offset(0, 0.05),
              child: _buildGridItem(result[index]),
            );
          },
        );
      },
    );
  }

  int _calculateCrossAxisCount(double width) {
    if (width < 600) return 1;
    if (width < 900) return 2;
    if (width < 1200) return 3;
    return 4;
  }

  Widget _buildGridItem(BangumiSubjectSearchData data) {
    return _GridSearchCard(data);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(
      header: buildHeader(context),
      content: Column(
        children: [
          buildSearch(),
          Expanded(child: buildResult()),
          if (controller.total > 0) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: PageWidget(controller),
    );
  }
}

class _GridSearchCard extends ConsumerStatefulWidget {
  final BangumiSubjectSearchData data;

  const _GridSearchCard(this.data);

  @override
  ConsumerState<_GridSearchCard> createState() => _GridSearchCardState();
}

class _GridSearchCardState extends ConsumerState<_GridSearchCard> {
  BangumiSubjectSearchData get subject => widget.data;
  String get label => subject.type?.label ?? '条目';

  Widget _buildCover() {
    var img = subject.images.common;
    if (img.isEmpty) {
      return Container(
        color: BTColors.surfaceSecondary(context),
        child: Center(
          child: Icon(
            FluentIcons.photo_error,
            size: 32,
            color: BTColors.textTertiary(context),
          ),
        ),
      );
    }

    var pathGet = Uri.parse(img).path;
    var rReg = RegExp(r'^/r/[^/]+/pic');
    if (rReg.hasMatch(pathGet)) pathGet = pathGet.replaceFirst(rReg, '/pic');

    return CachedNetworkImage(
      imageUrl: '${BtrBangumiApi.imageBaseUrl}/r/0x600$pathGet',
      fit: BoxFit.cover,
      progressIndicatorBuilder: (context, url, dp) => Center(
        child: ProgressRing(
          value: dp.progress == null ? 0 : dp.progress! * 100,
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: BTColors.surfaceSecondary(context),
        child: Center(
          child: Icon(
            FluentIcons.photo_error,
            size: 32,
            color: BTColors.textTertiary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildInfo() {
    var name = subject.nameCn == '' ? subject.name : subject.nameCn;
    var subTitle = subject.nameCn == '' ? '' : subject.name;

    return Padding(
      padding: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label == '条目' ? name : '[$label] $name',
            style: BTTypography.subtitle(context).copyWith(fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subTitle.isNotEmpty) ...[
            SizedBox(height: 2),
            Text(
              subTitle,
              style: BTTypography.caption(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: 6),
          _buildScoreChip(),
          SizedBox(height: 4),
          _buildMetaInfo(),
          const Spacer(),
          _buildCollectionInfo(),
          SizedBox(height: 4),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildMetaInfo() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (subject.date != null && subject.date!.isNotEmpty)
          _buildMetaChip(FluentIcons.calendar, subject.date!.split('-')[0]),
        if (subject.eps > 0)
          _buildMetaChip(FluentIcons.play, '${subject.eps}集'),
        if (subject.platform != null && subject.platform!.isNotEmpty)
          _buildMetaChip(FluentIcons.devices2, subject.platform!),
      ],
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: BTColors.textSecondary(context).withValues(alpha: 0.1),
        borderRadius: BTRadius.smallBR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: BTColors.textSecondary(context)),
          SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: BTColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionInfo() {
    var collect = subject.collection.collect ?? 0;
    var wish = subject.collection.wish ?? 0;

    if (collect == 0 && wish == 0) return const SizedBox.shrink();

    return Row(
      children: [
        if (collect > 0) ...[
          Icon(
            FluentIcons.heart_fill,
            size: 10,
            color: BTColors.textSecondary(context),
          ),
          SizedBox(width: 3),
          Text(
            '$collect',
            style: TextStyle(
              fontSize: 10,
              color: BTColors.textSecondary(context),
            ),
          ),
          SizedBox(width: 8),
        ],
        if (wish > 0) ...[
          Icon(
            FluentIcons.favorite_star_fill,
            size: 10,
            color: BTColors.textSecondary(context),
          ),
          SizedBox(width: 3),
          Text(
            '$wish',
            style: TextStyle(
              fontSize: 10,
              color: BTColors.textSecondary(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScoreChip() {
    var score = subject.rating.score;
    var scoreColor = _getScoreColor(score);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.15),
        borderRadius: BTRadius.smallBR,
        border: Border.all(color: scoreColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.favorite_star_fill, size: 10, color: scoreColor),
          SizedBox(width: 3),
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scoreColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    var paneTitle = subject.nameCn == '' ? subject.name : subject.nameCn;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Tooltip(
          message: '查看详情',
          child: GestureDetector(
            onTap: () => ref
                .read(navStoreProvider)
                .addNavItemB(
                  type: label,
                  subject: subject.id,
                  paneTitle: paneTitle,
                ),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: FluentTheme.of(
                    context,
                  ).accentColor.withValues(alpha: 0.1),
                  borderRadius: BTRadius.smallBR,
                ),
                child: Icon(
                  FluentIcons.open_in_new_tab,
                  size: 12,
                  color: FluentTheme.of(context).accentColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 8.0) return const Color(0xFF107C10);
    if (score >= 7.0) return const Color(0xFF0078D4);
    if (score >= 6.0) return const Color(0xFFFFB900);
    if (score >= 5.0) return const Color(0xFFFF8C00);
    return const Color(0xFFD13438);
  }

  @override
  Widget build(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return BTCard(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      useAcrylic: true,
      acrylicOpacity: 0.8,
      useReveal: true,
      useShadow: true,
      shadowLevel: BTShadowLevel.medium,
      borderColor: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.06),
      borderWidth: 1.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 1.0, child: _buildCover()),
          Expanded(child: _buildInfo()),
        ],
      ),
    );
  }
}

class _AnimatedSearchButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const _AnimatedSearchButton({
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<_AnimatedSearchButton> createState() => _AnimatedSearchButtonState();
}

class _AnimatedSearchButtonState extends State<_AnimatedSearchButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: BTTheme.animationDurationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(scale: _scaleAnimation.value, child: child);
          },
          child: AnimatedContainer(
            duration: BTTheme.animationDurationFast,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isHovered
                  ? accentColor
                  : accentColor.withValues(alpha: 0.9),
              borderRadius: BTRadius.mediumBR,
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: widget.isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: const ProgressRing(
                      strokeWidth: 2,
                      activeColor: Colors.white,
                    ),
                  )
                : Icon(FluentIcons.search, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _AnimatedSearchBox extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  const _AnimatedSearchBox({
    required this.controller,
    this.onSubmitted,
    this.onClear,
  });

  @override
  State<_AnimatedSearchBox> createState() => _AnimatedSearchBoxState();
}

class _AnimatedSearchBoxState extends State<_AnimatedSearchBox> {
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChange);
    _hasText = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChange() {
    var hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextBox(
            controller: widget.controller,
            focusNode: _focusNode,
            placeholder: '搜索条目名称...',
            placeholderStyle: TextStyle(
              color: BTColors.textTertiary(context),
              fontSize: 14,
            ),
            style: BTTypography.body(context),
            onSubmitted: widget.onSubmitted,
          ),
        ),
        if (_hasText) ...[
          SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onClear,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedOpacity(
                duration: BTTheme.animationDurationFast,
                opacity: _hasText ? 1.0 : 0.0,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: BTColors.textSecondary(
                      context,
                    ).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    FluentIcons.clear,
                    size: 12,
                    color: BTColors.textSecondary(context),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
        ] else
          SizedBox(width: 12),
      ],
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;

  const _FilterChip({
    required this.label,
    this.isSelected = false,
    this.onDeleted,
    this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: BTTheme.animationDurationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap?.call();
        },
        onTapCancel: () => _controller.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(scale: _scaleAnimation.value, child: child);
          },
          child: AnimatedContainer(
            duration: BTTheme.animationDurationFast,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? accentColor.withValues(alpha: _isHovered ? 1.0 : 0.9)
                  : (isDark
                        ? Colors.white.withValues(
                            alpha: _isHovered ? 0.1 : 0.05,
                          )
                        : Colors.black.withValues(
                            alpha: _isHovered ? 0.08 : 0.03,
                          )),
              borderRadius: BTRadius.roundBR,
              border: Border.all(
                color: widget.isSelected
                    ? accentColor
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.1)),
                width: 1,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isSelected
                        ? Colors.white
                        : BTColors.textPrimary(context),
                    fontSize: 13,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (widget.isSelected && widget.onDeleted != null) ...[
                  SizedBox(width: 6),
                  GestureDetector(
                    onTap: widget.onDeleted,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(
                        FluentIcons.chrome_close,
                        size: 10,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
