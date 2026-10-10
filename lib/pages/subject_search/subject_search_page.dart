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
import '../../widgets/common/bt_animations.dart';
import '../../widgets/common/empty_state.dart';
import 'subject_card_search.dart';
import 'subject_search_query.dart';

part 'subject_search_page/filters.dart';
part 'subject_search_page/results.dart';
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
    _addSearchTag(tag);
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

  void _addSearchTag(String value) {
    var tag = value.trim();
    if (tag.isEmpty) return;
    if (selectedTags.contains(tag)) {
      BTToast.show(context, message: '标签「$tag」已在搜索条件中', icon: FluentIcons.info);
      return;
    }
    setState(() => selectedTags.add(tag));
    BTToast.show(context, message: '已添加标签「$tag」', icon: FluentIcons.check_mark);
  }

  Future<void> _searchByTag(String value) async {
    var tag = value.trim();
    if (tag.isEmpty) return;
    setState(() {
      textController.clear();
      selectedTags
        ..clear()
        ..add(tag);
      addingTag = false;
      tagController.clear();
      _resetResults();
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

  /// dispose
  @override
  void dispose() {
    controller.dispose();
    textController.dispose();
    tagController.dispose();
    tagFocusNode.dispose();
    searchFocusNode.dispose();
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
    if (loading) return;
    if (addingTag) {
      if (tagController.text.trim().isEmpty) {
        _cancelTagInput();
      } else {
        _completeTagInput(tagController.text);
      }
    }
    var query = SubjectSearchQuery(
      keyword: textController.text,
      tags: selectedTags,
      types: types,
      sort: sort,
      nsfw: nsfw,
    );
    if (query.isEmpty) {
      _resetResults();
      setState(() {});
      await BtInfobar.warn(context, '请输入条目名称或添加标签');
      return;
    }
    if (types.isEmpty) {
      await BtInfobar.warn(context, '请至少选择一个搜索类型');
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
}

class _SubjectSearchPageState extends _SubjectSearchPageStateBase
    with _SubjectSearchFilters, _SubjectSearchResults {
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
