import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../components/app/app_dialog_resp.dart';
import '../../components/app/app_infobar.dart';
import '../../components/bangumi/search_subject/bss_card.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_enum_extension.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_subject.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../store/nav_store.dart';

/// 搜索页面
class BangumiSearchPage extends ConsumerStatefulWidget {
  /// 构造函数
  const BangumiSearchPage({super.key});

  @override
  ConsumerState<BangumiSearchPage> createState() => _BangumiSearchPageState();
}

/// 搜索页面状态
class _BangumiSearchPageState extends ConsumerState<BangumiSearchPage>
    with AutomaticKeepAliveClientMixin {
  /// api
  final BtrBangumiApi api = BtrBangumiApi();

  /// offset
  /// todo: 尽管返回的数据中有 limit、total、offset，但是无法设定 offset 实现分页
  /// 详见：https://github.com/bangumi/server/issues/532
  int offset = 0;

  /// text controller
  final TextEditingController textController = TextEditingController();

  /// 排序方式-label对照
  final sortMap = {
    'match': '匹配度',
    'heat': '收藏人数',
    'rank': '排名',
    'score': '评分',
  };

  /// 当前排序方式
  String sort = 'match';

  /// 当前搜索类型
  List<BangumiSubjectType> types = [BangumiSubjectType.anime];

  /// 是否显示NSFW
  bool? nsfw = false;

  /// nsfwList
  List nsfwList = [true, false, null];

  /// 搜索结果
  List<BangumiSubjectSearchData> result = [];

  /// 是否在加载中
  bool loading = false;

  /// 保持状态
  @override
  bool get wantKeepAlive => true;

  /// 搜索
  Future<void> search() async {
    var input = textController.text;
    if (input.isEmpty) {
      offset = 0;
      setState(() {});
      BtInfobar.warn(context, '请输入搜索内容');
      return;
    }
    if (types.isEmpty) {
      BtInfobar.warn(context, '请至少选择一个搜索类型');
      return;
    }
    if (loading) return;
    loading = true;
    result.clear();
    setState(() {});
    var resp = await api.searchSubjects(
      input,
      sort: sort,
      type: types,
      nsfw: nsfw,
    );
    if (resp.code != 0 || resp.data == null) {
      await showRespErr(resp, context);
      return;
    }
    var data = resp.data as BangumiPageT<BangumiSubjectSearchData>;
    result = data.data;
    loading = false;
    setState(() {});
  }

  /// 构建头部
  Widget buildHeader(BuildContext context) {
    return PageHeader(
      leading: IconButton(
        icon: Icon(FluentIcons.back),
        onPressed: () {
          ref.read(navStoreProvider).removeNavItem('Bangumi-条目搜索');
        },
      ),
      title: Text('Bangumi-条目搜索'),
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
      trailing: sort == key ? Icon(FluentIcons.check_mark) : null,
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

  /// 构建搜索类型选择
  Widget buildTypeSelects() {
    return DropDownButton(
      title: Text('搜索类型'),
      items: BangumiSubjectType.values
          .map((e) => MenuFlyoutItem(
                text: Text(e.label),
                selected: types.contains(e),
                trailing:
                    types.contains(e) ? Icon(FluentIcons.check_mark) : null,
                onPressed: () {
                  if (types.contains(e)) {
                    types.remove(e);
                  } else {
                    types.add(e);
                  }
                  setState(() {});
                },
              ))
          .toList(),
    );
  }

  /// 构建NSFW开关
  Widget buildNsfwCheck() {
    return Checkbox(
      checked: nsfw,
      onChanged: (value) {
        /// 查找现在的值在nsfwList中的位置
        var index = nsfwList.indexOf(nsfw);
        if (index == -1) {
          BtInfobar.error(context, '未知值');
          return;
        }
        nsfw = nsfwList[(index + 1) % nsfwList.length];
        setState(() {});
      },
      content: Text('NSFW'),
    );
  }

  /// 构建搜索框
  Widget buildSearch() {
    return Row(
      children: [
        SizedBox(width: 16.w),
        IconButton(
          icon: Icon(FluentIcons.search),
          onPressed: () async {
            await search();
          },
        ),
        SizedBox(width: 4.w),
        SizedBox(
          width: 600.w,
          child: TextBox(
            controller: textController,
            placeholder: '搜索内容',
          ),
        ),
        SizedBox(width: 8.w),
        buildTypeSelects(),
        SizedBox(width: 8.w),
        // todo 因为排序方式并不会影响搜索结果，所以暂时不显示
        // 详见：https://github.com/bangumi/server/issues/532
        // buildSortSelect(),
        // SizedBox(width: 8.w),
        buildNsfwCheck(),
      ],
    );
  }

  /// 构建列表
  Widget buildResult() {
    if (loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProgressRing(),
            SizedBox(height: 12.h),
            Text('加载中'),
          ],
        ),
      );
    }
    if (result.isEmpty) {
      return Center(
        child: Text('没有数据'),
      );
    }
    return GridView(
      controller: ScrollController(),
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 10 / 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      children: result.map(BssCard.new).toList(),
    );
  }

  /// 构建内容
  /// 主要分成两块，
  /// top-搜索框&加载更多
  /// bottom-搜索结果
  Widget buildContent() {
    return Column(children: [
      buildSearch(),
      Expanded(child: buildResult()),
    ]);
  }

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(header: buildHeader(context), content: buildContent());
  }
}