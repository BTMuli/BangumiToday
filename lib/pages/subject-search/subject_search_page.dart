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

part 'subject_search_page/filters.dart';
part 'subject_search_page/results.dart';
part 'subject_search_page/widgets.dart';

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
abstract class _SubjectSearchPageStateBase
    extends ConsumerState<SubjectSearchPage>
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
