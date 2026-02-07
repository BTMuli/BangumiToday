// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import 'rb_pw_bmf.dart';
import 'rb_pw_comicat.dart';
import 'rb_pw_mikan.dart';

/// Rss & Bmf
class RssBmfPage extends StatefulWidget {
  /// 构造函数
  const RssBmfPage({super.key});

  @override
  State<RssBmfPage> createState() => _RssBmfPageState();
}

/// Rss 页面状态
class _RssBmfPageState extends State<RssBmfPage>
    with AutomaticKeepAliveClientMixin {
  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// tabIndex
  int currentIndex = 0;

  /// 构建页面
  @override
  Widget build(BuildContext context) {
    super.build(context);
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
          selectedBackgroundColor: WidgetStateProperty.resolveWith(
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
          selectedBackgroundColor: WidgetStateProperty.resolveWith(
            (_) => FluentTheme.of(context).accentColor.withAlpha(80),
          ),
        ),
        Tab(
          icon: Image.asset('assets/images/platforms/comicat-favicon.ico'),
          text: const Text('Comicat'),
          body: const RbpComicatWidget(),
          semanticLabel: 'Comicat',
          selectedBackgroundColor: WidgetStateProperty.resolveWith(
            (_) => FluentTheme.of(context).accentColor.withAlpha(80),
          ),
        ),
      ],
      closeButtonVisibility: CloseButtonVisibilityMode.never,
      tabWidthBehavior: TabWidthBehavior.sizeToContent,
    );
  }
}
