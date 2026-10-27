// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// Project imports:
import '../../controller/page_controller.dart';
import '../../core/theme/bt_theme.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_subject.dart';
import '../../providers/app_providers.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../ui/bt_select.dart';
import '../../widgets/common/bt_animations.dart';
import '../../widgets/common/bt_drawer.dart';
import '../../widgets/common/empty_state.dart';
import 'subject_card_search.dart';
import 'subject_search_date_range.dart';
import 'subject_search_query.dart';

part 'subject_search_page/filter_drawer.dart';
part 'subject_search_page/filters.dart';
part 'subject_search_page/results.dart';
part 'subject_search_page/tags.dart';
part 'subject_search_page/widgets.dart';

/// 搜索页面
class SubjectSearchPage extends ConsumerStatefulWidget {
  /// 统一的搜索页标题与导航标识。
  static const title = '搜索';

  /// 初始标签筛选条件
  final List<String> initialTags;

  /// 构造函数
  const SubjectSearchPage({super.key, this.initialTags = const []});

  /// 打开统一搜索页；普通入口保留搜索状态，标签入口执行新的标签搜索。
  static void open(WidgetRef ref, {String? tag}) {
    var normalizedTag = tag?.trim() ?? '';
    var nav = ref.read(navStoreProvider);
    var index = nav.navItems.indexWhere((item) => item.title == title);
    var notifier = ref.read(navStoreProvider.notifier);
    if (normalizedTag.isEmpty && index != -1) {
      notifier.goIndex(nav.topNavCount + index);
      return;
    }
    notifier.addNavItem(
      PaneItem(
        icon: const Icon(FluentIcons.search),
        title: const Text(title),
        body: normalizedTag.isEmpty
            ? const SubjectSearchPage()
            : SubjectSearchPage(key: UniqueKey(), initialTags: [normalizedTag]),
      ),
      title,
    );
  }

  @override
  ConsumerState<SubjectSearchPage> createState() => _SubjectSearchPageState();
}

/// 搜索页面状态
abstract class _SubjectSearchPageStateBase
    extends ConsumerState<SubjectSearchPage>
    with AutomaticKeepAliveClientMixin {
  /// 当前标签筛选条件
  final List<String> selectedTags = [];
  final List<String> selectedMetaTags = [];
  bool tagIsMeta = false;
  bool tagDrawerOpen = false;
  bool filterDrawerOpen = false;
  final rangeControllers = {
    for (var key in [
      'dateFrom',
      'dateTo',
      'ratingFrom',
      'ratingTo',
      'rankFrom',
      'rankTo',
    ])
      key: TextEditingController(),
  };

  SubjectSearchQuery get _draftQuery => SubjectSearchQuery(
    keyword: textController.text,
    tags: selectedTags,
    metaTags: selectedMetaTags,
    types: types,
    sort: sort,
    nsfw: nsfw,
    dateFrom: rangeControllers['dateFrom']!.text,
    dateTo: rangeControllers['dateTo']!.text,
    ratingFrom: rangeControllers['ratingFrom']!.text,
    ratingTo: rangeControllers['ratingTo']!.text,
    rankFrom: rangeControllers['rankFrom']!.text,
    rankTo: rangeControllers['rankTo']!.text,
  );

  /// 是否正在输入新标签。
  bool addingTag = false;

  final TextEditingController tagController = TextEditingController();
  final FocusNode tagFocusNode = FocusNode();
  final FocusNode searchFocusNode = FocusNode();

  SubjectSearchQuery? _activeQuery;
  int _searchVersion = 0;

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
    selectedTags.addAll(SubjectSearchQuery(tags: widget.initialTags).tags);
    controller.onChanged = onPageChanged;
    if (selectedTags.isNotEmpty) Future.microtask(search);
  }

  void _beginTagInput() {
    setState(() => addingTag = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && addingTag) tagFocusNode.requestFocus();
    });
  }

  void _completeTagInput(String value) {
    var tag = value.trim();
    if (tag.isEmpty) {
      BTToast.show(context, message: '请输入标签内容', icon: FluentIcons.info);
      return;
    }
    _addSearchTag(tag, isMeta: tagIsMeta);
    setState(() {
      addingTag = false;
      tagController.clear();
    });
    searchFocusNode.requestFocus();
  }

  void _cancelTagInput() {
    setState(() {
      addingTag = false;
      tagController.clear();
    });
    searchFocusNode.requestFocus();
  }

  void _addSearchTag(String value, {bool isMeta = false}) {
    var tag = value.trim();
    if (tag.isEmpty) return;
    var selected = isMeta ? selectedMetaTags : selectedTags;
    if (selected.contains(tag)) {
      BTToast.show(context, message: '标签「$tag」已在搜索条件中', icon: FluentIcons.info);
      return;
    }
    setState(() => selected.add(tag));
    BTToast.show(context, message: '已添加标签「$tag」', icon: FluentIcons.check_mark);
  }

  Future<void> _searchByTag(String value, {bool isMeta = false}) async {
    var tag = value.trim();
    if (tag.isEmpty) return;
    setState(() {
      textController.clear();
      selectedTags.clear();
      selectedMetaTags.clear();
      (isMeta ? selectedMetaTags : selectedTags).add(tag);
      addingTag = false;
      tagController.clear();
      _resetResults();
    });
    await search();
  }

  Future<void> _openTagDrawer() async {
    if (tagDrawerOpen) return;
    setState(() => tagDrawerOpen = true);
    bool? apply;
    try {
      apply = await showBTDrawer<bool>(
        context: context,
        width: (MediaQuery.sizeOf(context).width - 24).clamp(0.0, 480.0),
        child: StatefulBuilder(
          builder: (drawerContext, updateDrawer) => BTDrawer(
            title: '热门标签',
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Consumer(
                      builder: (context, ref, child) => _SubjectTagPicker(
                        key: ValueKey(
                          ref.watch(
                            appStoreProvider.select(
                              (settings) => (
                                settings.bangumiUrl,
                                settings.bangumiUsePrivateApi,
                              ),
                            ),
                          ),
                        ),
                        types: List.of(types),
                        selectedTags: List.of(selectedTags),
                        onToggle: (tag) {
                          if (!mounted) return;
                          setState(() {
                            if (!selectedTags.remove(tag)) {
                              selectedTags.add(tag);
                            }
                          });
                          updateDrawer(() {});
                        },
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: BTColors.divider(drawerContext)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '已选 ${selectedTags.length} 个普通标签',
                          style: BTTypography.caption(drawerContext),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => Navigator.of(drawerContext).pop(true),
                        child: const Text('应用并搜索'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => tagDrawerOpen = false);
    }
    if (!mounted) return;
    if (apply ?? false) await search();
    if (!mounted) return;
    (addingTag ? tagFocusNode : searchFocusNode).requestFocus();
  }

  Future<void> _openFilterDrawer() async {
    if (filterDrawerOpen) return;
    setState(() => filterDrawerOpen = true);
    SubjectSearchQuery? ranges;
    try {
      ranges = await showBTDrawer<SubjectSearchQuery>(
        context: context,
        width: (MediaQuery.sizeOf(context).width - 24).clamp(0.0, 480.0),
        child: _SubjectFilterDrawer(initialQuery: _draftQuery),
      );
    } finally {
      if (mounted) setState(() => filterDrawerOpen = false);
    }
    if (!mounted || ranges == null) return;
    var values = {
      'dateFrom': ranges.dateFrom,
      'dateTo': ranges.dateTo,
      'ratingFrom': ranges.ratingFrom,
      'ratingTo': ranges.ratingTo,
      'rankFrom': ranges.rankFrom,
      'rankTo': ranges.rankTo,
    };
    setState(() {
      for (var entry in values.entries) {
        rangeControllers[entry.key]!.text = entry.value;
      }
    });
    await search();
  }

  void _resetResults() {
    _searchVersion++;
    _activeQuery = null;
    loading = false;
    offset = 0;
    totalResults = 0;
    result.clear();
    resultMap.clear();
    controller.reset(total: 0, cur: 0);
  }

  Future<void> _resetFilters({bool clearKeyword = false}) async {
    setState(() {
      if (clearKeyword) textController.clear();
      selectedTags.clear();
      selectedMetaTags.clear();
      tagController.clear();
      addingTag = false;
      tagIsMeta = false;
      sort = 'match';
      types = [BangumiSubjectType.anime];
      nsfw = false;
      for (var controller in rangeControllers.values) {
        controller.clear();
      }
      _resetResults();
    });
    if (textController.text.trim().isNotEmpty) await search();
  }

  /// dispose
  @override
  void dispose() {
    controller.dispose();
    textController.dispose();
    tagController.dispose();
    tagFocusNode.dispose();
    searchFocusNode.dispose();
    for (var controller in rangeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 页面改变
  Future<void> onPageChanged(int page) async {
    var query = _activeQuery;
    if (query == null || loading) return;
    if (resultMap.containsKey('page_$page')) {
      setState(() => result = resultMap['page_$page']!);
      return;
    }
    var searchVersion = _searchVersion;
    setState(() => loading = true);
    var repository = ref.read(bangumiRepositoryProvider);
    var resp = await repository.searchSubjects(
      query.keyword,
      sort: query.sort,
      type: query.types,
      nsfw: query.nsfw,
      offset: (page - 1) * limit,
      limit: limit,
      tag: query.tagFilter,
      metaTag: query.metaTagFilter,
      airdate: query.airdateFilter,
      rating: query.ratingFilter,
      rank: query.rankFilter,
    );
    if (!mounted || searchVersion != _searchVersion) return;
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
    if (addingTag) {
      if (tagController.text.trim().isEmpty) {
        _cancelTagInput();
      } else {
        _completeTagInput(tagController.text);
      }
    }
    var query = _draftQuery;
    var error = query.validationError;
    if (error != null) {
      await BtInfobar.warn(context, error);
      return;
    }
    _resetResults();
    _activeQuery = query;
    var searchVersion = _searchVersion;
    loading = true;
    setState(() {});
    var repository = ref.read(bangumiRepositoryProvider);
    var resp = await repository.searchSubjects(
      query.keyword,
      sort: query.sort,
      type: query.types,
      nsfw: query.nsfw,
      offset: offset,
      limit: limit,
      tag: query.tagFilter,
      metaTag: query.metaTagFilter,
      airdate: query.airdateFilter,
      rating: query.ratingFilter,
      rank: query.rankFilter,
    );
    if (!mounted || searchVersion != _searchVersion) return;
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
      onPressed: () async {
        if (sort == key) return;
        setState(() => sort = key);
        if (_activeQuery != null) await search();
      },
    );
  }

  /// 构建排序方式选择
  Widget buildSortSelect() {
    var label = sortMap[sort] ?? '未知';
    return DropDownButton(
      title: Text(label),
      placement: FlyoutPlacementMode.bottomLeft,
      items: sortMap.keys.map(buildSortItem).toList(),
    );
  }
}

class _SubjectSearchPageState extends _SubjectSearchPageStateBase
    with _SubjectSearchFilters, _SubjectSearchResults {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      header: buildHeader(context),
      content: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.55,
              ),
              child: SingleChildScrollView(child: buildSearch()),
            ),
            Expanded(child: buildResult()),
          ],
        ),
      ),
    );
  }
}
