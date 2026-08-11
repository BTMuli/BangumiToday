// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../controller/page_controller.dart';
import '../../core/theme/bt_theme.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_subject.dart';
import '../../providers/app_providers.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/bangumi/subject_card/bsc_search.dart';
import '../../widgets/common/bt_animations.dart';
import '../../widgets/common/empty_state.dart';

/// 搜索页面
class SubjectSearchPage extends ConsumerStatefulWidget {
  /// 初始标签筛选条件
  final String? tag;

  /// 构造函数
  const SubjectSearchPage({super.key, this.tag});

  /// 获取搜索页标题
  static String titleForTag(String? tag) {
    var normalizedTag = tag?.trim();
    if (normalizedTag == null || normalizedTag.isEmpty) {
      return 'Bangumi-条目搜索';
    }
    return 'Bangumi-标签搜索：$normalizedTag';
  }

  @override
  ConsumerState<SubjectSearchPage> createState() => _SubjectSearchPageState();
}

/// 搜索页面状态
class _SubjectSearchPageState extends ConsumerState<SubjectSearchPage>
    with AutomaticKeepAliveClientMixin {
  /// 当前标签筛选条件
  String? selectedTag;

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

  /// 保持状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化函数
  @override
  void initState() {
    super.initState();
    selectedTag = _normalizeTag(widget.tag);
    controller.onChanged = onPageChanged;
    if (selectedTag != null) Future.microtask(search);
  }

  String? _normalizeTag(String? value) {
    var normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  void _searchByTag(String tag) {
    var normalizedTag = _normalizeTag(tag);
    if (normalizedTag == null) return;

    var title = SubjectSearchPage.titleForTag(normalizedTag);
    ref
        .read(navStoreProvider)
        .addNavItem(
          PaneItem(
            icon: const Icon(FluentIcons.search),
            title: Text(title),
            body: SubjectSearchPage(tag: normalizedTag),
          ),
          title,
        );
  }

  List<String>? get tagFilter {
    return selectedTag == null ? null : [selectedTag!];
  }

  String get pageTitle => SubjectSearchPage.titleForTag(widget.tag);

  @override
  void didUpdateWidget(SubjectSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag == widget.tag) return;

    selectedTag = _normalizeTag(widget.tag);
    _resetResults();
    if (selectedTag != null) Future.microtask(search);
  }

  void _resetResults() {
    offset = 0;
    totalResults = 0;
    result.clear();
    resultMap.clear();
    controller.reset(total: 0, cur: 0);
  }

  /// dispose
  @override
  void dispose() {
    controller.dispose();
    textController.dispose();
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
      tag: tagFilter,
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
    var input = textController.text.trim();
    if (input.isEmpty && selectedTag == null) {
      _resetResults();
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
    _resetResults();
    setState(() {});
    var repository = ref.read(bangumiRepositoryProvider);
    var resp = await repository.searchSubjects(
      input,
      sort: sort,
      type: types,
      nsfw: nsfw,
      offset: offset,
      limit: limit,
      tag: tagFilter,
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
          ref.read(navStoreProvider).removeNavItem(pageTitle);
        },
      ),
      title: Text(
        pageTitle,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      ),
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
          padding: EdgeInsets.only(right: 6),
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
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              SizedBox(width: 10),
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
              SizedBox(width: 10),
              buildTypeSelects(),
              SizedBox(width: 6),
              buildNsfwCheck(),
            ],
          ),
          if (types.isNotEmpty || selectedTag != null) ...[
            SizedBox(height: 8),
            _buildSelectedFilterChips(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedFilterChips() {
    var chips = types.map((type) {
      return _FilterChip(
        label: type.label,
        isSelected: true,
        onDeleted: () {
          setState(() {
            types.remove(type);
          });
        },
      );
    }).toList();
    if (selectedTag != null) {
      chips.add(
        _FilterChip(
          label: '标签: $selectedTag',
          isSelected: true,
          onDeleted: () {
            selectedTag = null;
            _resetResults();
            setState(() {});
          },
        ),
      );
    }
    return Wrap(spacing: 6, runSpacing: 4, children: chips);
  }

  Widget buildResult() {
    if (loading) {
      return BTEmptyState.loading(message: '正在搜索...');
    }
    if (controller.total == 0) {
      return BTEmptyState.noSearchResult(
        keyword: textController.text.isEmpty
            ? selectedTag
            : textController.text,
        actionText: '清除搜索',
        onAction: () {
          textController.clear();
          selectedTag = null;
          _resetResults();
          setState(() {});
        },
      );
    }
    return Column(
      children: [
        _buildResultSummary(),
        Expanded(child: _buildTwoColumnListView()),
      ],
    );
  }

  Widget _buildResultSummary() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
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
              ],
            ),
          ),
          if (controller.total > 1) ...[
            SizedBox(width: 8),
            PageWidget(controller),
          ],
        ],
      ),
    );
  }

  Widget _buildTwoColumnListView() {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 168,
      ),
      itemCount: result.length,
      itemBuilder: (context, index) {
        return BTFadeSlideIn(
          duration: const Duration(milliseconds: 300),
          delay: Duration(milliseconds: index * 50),
          offset: const Offset(0, 0.05),
          child: BscSearch(result[index], onTagTap: _searchByTag),
        );
      },
    );
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
            padding: EdgeInsets.all(10),
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
                : Icon(FluentIcons.search, size: 14, color: Colors.white),
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
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    fontSize: 12,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (widget.isSelected && widget.onDeleted != null) ...[
                  SizedBox(width: 4),
                  GestureDetector(
                    onTap: widget.onDeleted,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(
                        FluentIcons.chrome_close,
                        size: 9,
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
