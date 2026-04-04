import 'dart:math';

import 'package:dart_rss/domain/rss_item.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../core/services/optimized_rss_service.dart';
import '../../database/app/app_config.dart';
import '../../domain/repositories/bmf_repository.dart';
import '../../plugins/mikan/mikan_api.dart';
import '../../store/app_store.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/common/virtual_list.dart';
import '../../widgets/rss/rss_mk_card2.dart';

class OptimizedRbpMikanWidget extends ConsumerStatefulWidget {
  const OptimizedRbpMikanWidget({super.key});

  @override
  ConsumerState<OptimizedRbpMikanWidget> createState() =>
      _OptimizedRbpMikanWidgetState();
}

class _OptimizedRbpMikanWidgetState
    extends ConsumerState<OptimizedRbpMikanWidget>
    with AutomaticKeepAliveClientMixin {
  final BtrMikanApi mikanAPI = BtrMikanApi();
  final OptimizedRssService _rssService = OptimizedRssService.instance;

  List<RssItem> _allItems = [];
  final List<RssItem> _displayItems = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 50;

  late String token = '';
  late bool useUserRSS = false;

  final BtsAppConfig sqlite = BtsAppConfig();

  String? get mikanRss => ref.watch(appStoreProvider).mikanRss;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, init);
  }

  Future<void> refreshMikanRSS({bool forceRefresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _allItems.clear();
      _displayItems.clear();
    });

    try {
      var baseUrl = mikanRss ?? 'https://mikanani.me';
      var url = '$baseUrl/RSS/Classic';

      var result = await _rssService.fetchRssIncremental(
        url,
        forceRefresh: forceRefresh,
      );

      if (result.code == 0 && result.data != null) {
        _allItems = result.data!.allItems;
        _hasMore = _allItems.length > _pageSize;
        _loadPage(0);

        if (mounted) {
          var message = result.data!.hasNewItems
              ? '已刷新Mikan列表，新增${result.data!.newItems.length}条'
              : '已刷新Mikan列表';
          await BtInfobar.success(context, message);
        }
      } else {
        if (mounted) await showRespErr(result, context);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> refreshUserRSS({bool forceRefresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _allItems.clear();
      _displayItems.clear();
    });

    try {
      var baseUrl = mikanRss ?? 'https://mikanani.me';
      var url = '$baseUrl/RSS/MyBangumi?token=$token';

      var result = await _rssService.fetchRssIncremental(
        url,
        forceRefresh: forceRefresh,
      );

      if (result.code == 0 && result.data != null) {
        _allItems = result.data!.allItems;
        _hasMore = _allItems.length > _pageSize;
        _loadPage(0);

        if (mounted) {
          var message = result.data!.hasNewItems
              ? '已刷新用户列表，新增${result.data!.newItems.length}条'
              : '已刷新用户列表';
          await BtInfobar.success(context, message);
        }
      } else {
        if (mounted) await showRespErr(result, context);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadPage(int page) {
    var start = page * _pageSize;
    var end = min(start + _pageSize, _allItems.length);

    if (start < _allItems.length) {
      _displayItems.addAll(_allItems.sublist(start, end));
      _currentPage = page;
      _hasMore = end < _allItems.length;
    }
  }

  void _loadMore() {
    if (!_hasMore || _isLoading) return;
    _loadPage(_currentPage + 1);
    setState(() {});
  }

  Future<void> init() async {
    var mikan = await sqlite.readMikanToken();
    if (mikan == null || mikan.isEmpty) {
      useUserRSS = false;
      await refreshMikanRSS();
      return;
    }
    token = mikan;
    useUserRSS = true;
    await refreshUserRSS();
  }

  Future<String> getToken(String token) async {
    if (await canLaunchUrlString(token)) {
      var link = Uri.parse(token);
      return link.queryParameters['token'] ?? token;
    }
    return token;
  }

  Future<void> tryEditToken() async {
    var input = await showInput(
      context,
      title: '输入 Token',
      content: '请输入你的 Token\n（在蜜柑计划的个人中心可以找到）',
    );
    if (input == null || input == "") {
      if (mounted) await BtInfobar.warn(context, '未输入 Token');
      return;
    }
    var parsed = await getToken(input);
    if (parsed == token) {
      if (mounted) await BtInfobar.warn(context, 'Token 未变更');
      return;
    }
    token = parsed;
    await sqlite.writeMikanToken(token);
    if (mounted) await BtInfobar.success(context, 'Token 已保存');
    useUserRSS = true;
    setState(() {});
  }

  Future<void> tryEditUrl() async {
    var url = await sqlite.readMikanUrl();
    if (url == null || url.isEmpty) url = defaultMikanMirror;
    if (mounted) {
      var input = await showInput(
        context,
        title: '输入 URL',
        content: '请输入你的 Mikan URL\n（默认为 $defaultMikanMirror）',
        value: url,
      );
      if (input == null || input == "") {
        if (mounted) {
          var check = await showConfirm(
            context,
            title: '确认清空 URL？',
            content: '将使用默认地址 $defaultMikanMirror',
          );
          if (!check) return;
        }
        await ref
            .read(appStoreProvider.notifier)
            .setMikanRss(defaultMikanMirror);
        return;
      }
      if (input == url) {
        if (mounted) await BtInfobar.warn(context, 'URL 未变更');
        return;
      }
      if (mounted) {
        var confirm = await showConfirm(
          context,
          title: '确认更改 URL？',
          content: '将同步修改RSS源地址',
        );
        if (!confirm) return;
      }
      if (input.endsWith("/")) input = input.substring(0, input.length - 1);
      var repo = ref.read(bmfRepositoryProvider);
      await repo.updateMikanUrl(input, url);
      await ref.read(appStoreProvider.notifier).setMikanRss(input);
      if (mounted) await BtInfobar.success(context, 'URL 已保存');
    }
  }

  Widget buildTitle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        IconButton(
          icon: Image.asset(
            'assets/images/platforms/mikan-logo.png',
            height: 30.h,
            fit: BoxFit.cover,
          ),
          onPressed: () async {
            await launchUrlString('https://mikanani.me/');
          },
        ),
        Image.asset(
          'assets/images/platforms/mikan-text.png',
          height: 30.h,
          fit: BoxFit.cover,
        ),
        SizedBox(width: 10.w),
        IconButton(
          icon: Icon(FluentIcons.refresh, size: 15.sp),
          onPressed: () {
            if (useUserRSS) {
              refreshUserRSS(forceRefresh: true);
            } else {
              refreshMikanRSS(forceRefresh: true);
            }
          },
        ),
        SizedBox(width: 10.w),
        ...buildTokenBar(),
        SizedBox(width: 10.w),
        Text('共 ${_allItems.length} 条', style: TextStyle(fontSize: 12.sp)),
      ],
    );
  }

  List<Widget> buildTokenBar() {
    return [
      ToggleSwitch(
        checked: useUserRSS,
        onChanged: (v) async {
          var old = useUserRSS;
          useUserRSS = v;
          if (token == '' && v) {
            useUserRSS = false;
            await BtInfobar.warn(context, '未设置 Token');
            return;
          } else if (!v && _allItems.isEmpty) {
            await refreshMikanRSS();
          } else if (v && _allItems.isEmpty) {
            await refreshUserRSS();
          }
          if (v != old) {
            if (v) {
              if (mounted) await BtInfobar.success(context, '已切换到用户列表');
            } else {
              if (mounted) await BtInfobar.success(context, '已切换到Mikan列表');
            }
          }
          setState(() {});
        },
      ),
      SizedBox(width: 10.w),
      FilledButton(onPressed: null, child: Text('Token: $token')),
      SizedBox(width: 10.w),
      Button(onPressed: tryEditToken, child: const Text('编辑Token')),
      SizedBox(width: 10.w),
      Button(onPressed: tryEditUrl, child: const Text('编辑URL')),
    ];
  }

  Widget buildContent() {
    if (_isLoading && _displayItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ProgressRing(),
            SizedBox(height: 20.h),
            const Text('正在加载数据...'),
          ],
        ),
      );
    }

    if (_displayItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(FluentIcons.mail, size: 48),
            SizedBox(height: 16.h),
            const Text('暂无数据'),
          ],
        ),
      );
    }

    return VirtualListView<RssItem>(
      items: _displayItems,
      itemHeight: 200,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      isLoading: _isLoading,
      hasMore: _hasMore,
      onLoadMore: _loadMore,
      emptyPlaceholder: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(FluentIcons.mail, size: 48),
            SizedBox(height: 16.h),
            const Text('暂无数据'),
          ],
        ),
      ),
      itemBuilder: (context, item, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: RssMikanCard2(item),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage.withPadding(
      padding: EdgeInsets.zero,
      header: Padding(padding: EdgeInsets.all(8), child: buildTitle()),
      content: buildContent(),
    );
  }
}
