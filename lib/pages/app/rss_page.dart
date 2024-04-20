import 'package:fluent_ui/fluent_ui.dart';

import '../../components/rss/rss_cmc_page.dart';
import '../../components/rss/rss_mk_page.dart';

/// 负责各种 rss 页面的显示
/// 目前包括 MikanRss 和 ComicatRss
class RssPage extends StatefulWidget {
  /// 构造函数
  const RssPage({super.key});

  @override
  State<RssPage> createState() => _RssPageState();
}

/// Rss 页面状态
class _RssPageState extends State<RssPage> with AutomaticKeepAliveClientMixin {
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
          icon: Image.asset(
            'assets/images/platforms/mikan-favicon.ico',
            height: 16,
          ),
          text: const Text('Mikan'),
          body: const RssMkPage(),
          semanticLabel: 'Mikan',
        ),
        Tab(
          icon: Image.asset('assets/images/platforms/comicat-favicon.ico'),
          text: const Text('Comicat'),
          body: const RssCmcPage(),
          semanticLabel: 'Comicat',
        ),
      ],
      closeButtonVisibility: CloseButtonVisibilityMode.never,
      tabWidthBehavior: TabWidthBehavior.sizeToContent,
    );
  }
}
