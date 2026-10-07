// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../providers/app_providers.dart';
import 'rss_bmf_anibt.dart';
import 'rss_bmf_comicat.dart';
import 'rss_bmf_mikan.dart';
import 'rss_bmf_workspace.dart';

/// Rss & Bmf
class RssBmfPage extends ConsumerStatefulWidget {
  /// 构造函数
  const RssBmfPage({super.key});

  @override
  ConsumerState<RssBmfPage> createState() => _RssBmfPageState();
}

/// Rss 页面状态
class _RssBmfPageState extends ConsumerState<RssBmfPage>
    with AutomaticKeepAliveClientMixin {
  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// tabIndex
  int currentIndex = 0;
  final ValueNotifier<int> _selectedTab = ValueNotifier(0);
  int _handledNavigationRequest = 0;
  // TabView 按 Tab 对象身份保留页体，必须在重建时复用同一组 Tab。
  late final List<Tab> _tabs = _createTabs();

  @override
  void dispose() {
    _selectedTab.dispose();
    super.dispose();
  }

  Widget _tabBody(int index, Widget body) => ValueListenableBuilder<int>(
    valueListenable: _selectedTab,
    child: body,
    builder: (_, selected, child) =>
        TickerMode(enabled: selected == index, child: child!),
  );

  /// 构建页面
  @override
  Widget build(BuildContext context) {
    super.build(context);
    var navigation = ref.watch(bmfNavigationProvider);
    if (navigation.requestId != _handledNavigationRequest) {
      _handledNavigationRequest = navigation.requestId;
      currentIndex = 0;
      _selectedTab.value = currentIndex;
    }
    return TabView(
      currentIndex: currentIndex,
      onChanged: (index) {
        currentIndex = index;
        _selectedTab.value = index;
        setState(() {});
      },
      tabs: _tabs,
      closeButtonVisibility: CloseButtonVisibilityMode.never,
      tabWidthBehavior: TabWidthBehavior.equal,
      minTabWidth: 80,
      maxTabWidth: 120,
    );
  }

  List<Tab> _createTabs() {
    return [
      Tab(
        icon: Image.asset('assets/images/logo.png', height: 16, width: 16),
        text: const Text('BMF'),
        body: _tabBody(0, const RssBmfWorkspace()),
        semanticLabel: 'BMF',
        selectedBackgroundColor: WidgetStateColor.resolveWith(
          (_) => FluentTheme.of(context).accentColor.withAlpha(80),
        ),
      ),
      Tab(
        icon: Image.asset(
          'assets/images/platforms/anibt-favicon.ico',
          height: 16,
          width: 16,
          fit: BoxFit.contain,
        ),
        text: const Text('AniBT'),
        body: _tabBody(1, const RssBmfAnibt()),
        semanticLabel: 'AniBT',
        selectedBackgroundColor: WidgetStateColor.resolveWith(
          (_) => FluentTheme.of(context).accentColor.withAlpha(80),
        ),
      ),
      Tab(
        icon: Image.asset(
          'assets/images/platforms/mikan-favicon.ico',
          height: 16,
        ),
        text: const Text('Mikan'),
        body: _tabBody(2, const RssBmfMikan()),
        semanticLabel: 'Mikan',
        selectedBackgroundColor: WidgetStateColor.resolveWith(
          (_) => FluentTheme.of(context).accentColor.withAlpha(80),
        ),
      ),
      Tab(
        icon: Image.asset('assets/images/platforms/comicat-favicon.ico'),
        text: const Text('Comicat'),
        body: _tabBody(3, const RssBmfComicat()),
        semanticLabel: 'Comicat',
        selectedBackgroundColor: WidgetStateColor.resolveWith(
          (_) => FluentTheme.of(context).accentColor.withAlpha(80),
        ),
      ),
    ];
  }
}
