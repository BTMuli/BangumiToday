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
  int _handledNavigationRequest = 0;
  // TabView 按 Tab 对象身份保留页体，必须在重建时复用同一组 Tab。
  late final List<Tab> _tabs = _createTabs();

  /// 构建页面
  @override
  Widget build(BuildContext context) {
    super.build(context);
    var navigation = ref.watch(bmfNavigationProvider);
    if (navigation.requestId != _handledNavigationRequest) {
      _handledNavigationRequest = navigation.requestId;
      currentIndex = 0;
    }
    return TabView(
      currentIndex: currentIndex,
      onChanged: (index) {
        currentIndex = index;
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
        body: const RssBmfWorkspace(),
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
        body: const RssBmfAnibt(),
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
        body: const RssBmfMikan(),
        semanticLabel: 'Mikan',
        selectedBackgroundColor: WidgetStateColor.resolveWith(
          (_) => FluentTheme.of(context).accentColor.withAlpha(80),
        ),
      ),
      Tab(
        icon: Image.asset('assets/images/platforms/comicat-favicon.ico'),
        text: const Text('Comicat'),
        body: const RssBmfComicat(),
        semanticLabel: 'Comicat',
        selectedBackgroundColor: WidgetStateColor.resolveWith(
          (_) => FluentTheme.of(context).accentColor.withAlpha(80),
        ),
      ),
    ];
  }
}
