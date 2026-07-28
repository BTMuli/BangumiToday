// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../providers/app_providers.dart';
import 'rb_pw_anibt.dart';
import 'rb_pw_bmf.dart';
import 'rb_pw_comicat.dart';
import 'rb_pw_mikan.dart';

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

  /// 构建页面
  @override
  Widget build(BuildContext context) {
    super.build(context);
    var navigation = ref.watch(bmfNavigationProvider);
    if (navigation.requestId != _handledNavigationRequest &&
        navigation.targetSubject != null) {
      _handledNavigationRequest = navigation.requestId;
      currentIndex = 0;
    }
    return TabView(
      currentIndex: currentIndex,
      onChanged: (index) {
        currentIndex = index;
        setState(() {});
      },
      tabs: [
        Tab(
          icon: Image.asset('assets/images/logo.png', height: 16, width: 16),
          text: const Text('BMF'),
          body: const RbpBmfWidget(),
          semanticLabel: 'BMF',
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
          body: const RbpMikanWidget(),
          semanticLabel: 'Mikan',
          selectedBackgroundColor: WidgetStateColor.resolveWith(
            (_) => FluentTheme.of(context).accentColor.withAlpha(80),
          ),
        ),
        Tab(
          icon: Image.asset('assets/images/platforms/comicat-favicon.ico'),
          text: const Text('Comicat'),
          body: const RbpComicatWidget(),
          semanticLabel: 'Comicat',
          selectedBackgroundColor: WidgetStateColor.resolveWith(
            (_) => FluentTheme.of(context).accentColor.withAlpha(80),
          ),
        ),
        Tab(
          icon: const Icon(FluentIcons.play_solid, size: 16),
          text: const Text('AniBT'),
          body: const RbpAnibtWidget(),
          semanticLabel: 'AniBT',
          selectedBackgroundColor: WidgetStateColor.resolveWith(
            (_) => FluentTheme.of(context).accentColor.withAlpha(80),
          ),
        ),
      ],
      closeButtonVisibility: CloseButtonVisibilityMode.never,
      tabWidthBehavior: TabWidthBehavior.equal,
      minTabWidth: 80,
      maxTabWidth: 120,
    );
  }
}
