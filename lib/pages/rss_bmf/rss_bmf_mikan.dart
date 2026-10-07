// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../database/app/app_mikan_credential.dart';
import '../../models/rss/rss.dart';
import '../../request/mikan/mikan_api.dart';
import '../../store/app_store.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/rss/rss_release_data.dart';
import 'mikan_mirror_combo.dart';
import 'rss_auto_refresh.dart';
import 'rss_release_list.dart';

/// 负责 MikanProject RSS 页面的显示
/// 包括 RSSClassic 和 RSSPersonal
/// 前者是列表模式显示站点的RSS更新，后者是个人订阅的RSS更新
class RssBmfMikan extends ConsumerStatefulWidget {
  /// 构造函数
  const RssBmfMikan({super.key});

  @override
  ConsumerState<RssBmfMikan> createState() => _RssBmfMikanState();
}

/// MikanRSS 页面状态
class _RssBmfMikanState extends ConsumerState<RssBmfMikan>
    with AutomaticKeepAliveClientMixin {
  /// 请求客户端
  final BtrMikanApi mikanAPI = BtrMikanApi();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  List<RssItem> _searchItems = [];
  bool _searchLoaded = false;
  int _requestId = 0;

  bool get _isSearch => _query.isNotEmpty;

  /// RSS 数据
  List<RssItem> rssItems = [];

  /// RSS 数据
  List<RssItem> userItems = [];

  /// 用户订阅的 token
  late String token = '';

  /// 是否使用用户订阅
  late bool useUserRSS = false;

  bool _initialized = false;
  bool _refreshing = false;
  bool _mikanLoaded = false;
  bool _userLoaded = false;
  bool _loadFailed = false;
  DateTime? _mikanUpdated;
  DateTime? _userUpdated;
  DateTime? _searchUpdated;
  DateTime? _mikanAttempt;
  DateTime? _userAttempt;
  DateTime? _searchAttempt;

  DateTime? get _lastUpdated => _isSearch
      ? _searchUpdated
      : useUserRSS
      ? _userUpdated
      : _mikanUpdated;

  DateTime? get _lastAttempt => _isSearch
      ? _searchAttempt
      : useUserRSS
      ? _userAttempt
      : _mikanAttempt;

  /// mikan 镜像
  String get mikanRss => ref.read(appStoreProvider).mikanRss;

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.delayed(Duration.zero, init));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 刷新
  Future<void> refreshMikanRSS() => _refreshRSS(personal: false);

  /// 刷新
  Future<void> refreshUserRSS() => _refreshRSS(personal: true);

  Future<void> _refreshRSS({
    required bool personal,
    bool notify = true,
    bool reportErrors = true,
  }) async {
    if (!mounted) return;
    var requestId = ++_requestId;
    var query = _query;
    setState(() {
      _refreshing = true;
      _loadFailed = false;
      var at = DateTime.now();
      if (query.isNotEmpty) {
        _searchAttempt = at;
      } else if (personal) {
        _userAttempt = at;
      } else {
        _mikanAttempt = at;
      }
    });
    var resGet = query.isNotEmpty
        ? await mikanAPI.searchRSS(query)
        : personal
        ? await mikanAPI.getUserRSS(token)
        : await mikanAPI.getClassicRSS();
    if (!mounted || requestId != _requestId) return;
    var success = resGet.code == 0 && resGet.data != null;
    setState(() {
      _refreshing = false;
      _loadFailed = !success;
      if (success) {
        if (query.isNotEmpty) {
          _searchItems = resGet.data!;
          _searchLoaded = true;
          _searchUpdated = DateTime.now();
        } else if (personal) {
          userItems = resGet.data!;
          _userLoaded = true;
          _userUpdated = DateTime.now();
        } else {
          rssItems = resGet.data!;
          _mikanLoaded = true;
          _mikanUpdated = DateTime.now();
        }
      }
    });
    if (!success) {
      if (reportErrors) await showRespErr(resGet, context);
      return;
    }
    if (notify) {
      await BtInfobar.success(
        context,
        query.isNotEmpty
            ? '已刷新 Mikan 搜索结果'
            : personal
            ? '已刷新用户列表'
            : '已刷新 Mikan 列表',
      );
    }
  }

  Future<void> _search() async {
    if (!_initialized) return;
    var query = _searchController.text.trim();
    setState(() {
      if (_query != query) {
        _searchItems = [];
        _searchLoaded = false;
        _searchUpdated = null;
        _searchAttempt = null;
      }
      _query = query;
    });
    await _refreshRSS(personal: useUserRSS, notify: false);
  }

  Future<void> _clearSearch() async {
    _searchController.clear();
    if (_isSearch) await _search();
  }

  Future<void> _reloadMirror() async {
    if (!_initialized) return;
    setState(() {
      rssItems = [];
      userItems = [];
      _searchItems = [];
      _mikanLoaded = false;
      _userLoaded = false;
      _searchLoaded = false;
      _mikanUpdated = null;
      _userUpdated = null;
      _searchUpdated = null;
      _mikanAttempt = null;
      _userAttempt = null;
      _searchAttempt = null;
    });
    await _refreshRSS(personal: useUserRSS, notify: false);
  }

  /// 初始化
  Future<void> init() async {
    var mikan = await BtsMikanCredential().readToken();
    if (!mounted) return;
    _initialized = true;
    if (mikan == null || mikan.isEmpty) {
      useUserRSS = false;
      await _refreshRSS(personal: false, notify: false);
      return;
    }
    token = mikan;
    useUserRSS = true;
    await _refreshRSS(personal: true, notify: false);
  }

  /// 解析 token
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
    await BtsMikanCredential().writeToken(parsed);
    if (!mounted) return;
    _searchController.clear();
    setState(() {
      token = parsed;
      _query = '';
      userItems = [];
      _userLoaded = false;
      _userUpdated = null;
      _userAttempt = null;
      useUserRSS = true;
    });
    await BtInfobar.success(context, 'Token 已保存');
    await refreshUserRSS();
  }

  Future<void> _switchFeed(bool personal) async {
    if (!_initialized || (!_isSearch && useUserRSS == personal)) return;
    if (personal && token.isEmpty) {
      await tryEditToken();
      return;
    }
    _searchController.clear();
    setState(() {
      ++_requestId;
      _query = '';
      useUserRSS = personal;
      _refreshing = false;
      _loadFailed = false;
    });
    if (personal && !_userLoaded) {
      await refreshUserRSS();
    } else if (!personal && !_mikanLoaded) {
      await refreshMikanRSS();
    }
  }

  Widget _buildSearch() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) => TextBox(
        controller: _searchController,
        enabled: _initialized,
        placeholder: '搜索 Mikan 全站资源标题、字幕组或格式',
        textInputAction: TextInputAction.search,
        prefix: const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Icon(FluentIcons.search, size: 14),
        ),
        suffix: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value.text.isNotEmpty || _isSearch)
              Tooltip(
                message: '清除搜索，返回更新列表',
                child: IconButton(
                  icon: const Icon(FluentIcons.clear, size: 12),
                  onPressed: _initialized ? _clearSearch : null,
                ),
              ),
            Tooltip(
              message: '搜索 Mikan 全站（Enter）',
              child: IconButton(
                icon: const Icon(FluentIcons.search, size: 14),
                onPressed: _initialized ? _search : null,
              ),
            ),
          ],
        ),
        onSubmitted: (_) => unawaited(_search()),
      ),
    );
  }

  Widget buildTitle() {
    return Row(
      children: [
        Tooltip(
          message: '打开蜜柑计划',
          child: IconButton(
            icon: Image.asset(
              'assets/images/platforms/mikan-logo.png',
              width: 30,
              height: 30,
            ),
            onPressed: () => launchUrlString(
              _isSearch
                  ? Uri.parse(mikanRss)
                        .resolve('/Home/Search')
                        .replace(queryParameters: {'searchstr': _query})
                        .toString()
                  : mikanRss,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mikan', style: BTTypography.title(context)),
              Text(
                _isSearch
                    ? '全站搜索：$_query'
                    : useUserRSS
                    ? '个人订阅的最新资源'
                    : '蜜柑计划最近发布的资源',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BTTypography.caption(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildContent(List<RssItem> data) {
    return RssReleaseList(
      title: buildTitle(),
      searchControl: _buildSearch(),
      useLocalFilters: false,
      isSearch: _isSearch,
      onClearSearch: _clearSearch,
      refreshEnabled: _initialized,
      leadingControls: [
        ToggleButton(
          checked: !_isSearch && !useUserRSS,
          onChanged: !_initialized ? null : (_) => _switchFeed(false),
          child: const Text('站点更新'),
        ),
        ToggleButton(
          checked: !_isSearch && useUserRSS,
          onChanged: !_initialized ? null : (_) => _switchFeed(true),
          child: const Text('个人订阅'),
        ),
      ],
      sourceControls: [
        const Tooltip(
          message: 'Mikan 访问地址',
          child: MikanMirrorCombo(width: 176),
        ),
        Tooltip(
          message: token.isEmpty ? '设置 Token 后可查看个人订阅' : '个人订阅 Token 已设置',
          child: Button(
            onPressed: _refreshing || !_initialized ? null : tryEditToken,
            child: Text(token.isEmpty ? '设置 Token' : '编辑 Token'),
          ),
        ),
      ],
      items: data,
      source: RssReleaseSource.mikan,
      refreshing: _refreshing,
      loaded:
          (_isSearch
              ? _searchLoaded
              : useUserRSS
              ? _userLoaded
              : _mikanLoaded) ||
          _loadFailed,
      loadFailed: _loadFailed,
      lastUpdated: _lastUpdated,
      onRefresh: useUserRSS ? refreshUserRSS : refreshMikanRSS,
    );
  }

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(appStoreProvider.select((store) => store.mikanRss), (_, _) {
      unawaited(_reloadMirror());
    });
    return RssAutoRefresh(
      enabled: _initialized,
      refreshing: _refreshing,
      lastUpdated: _lastUpdated,
      lastAttempt: _lastAttempt,
      onRefresh: () =>
          _refreshRSS(personal: useUserRSS, notify: false, reportErrors: false),
      child: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: buildContent(
          _isSearch
              ? _searchItems
              : useUserRSS
              ? userItems
              : rssItems,
        ),
      ),
    );
  }
}
