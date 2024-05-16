// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../components/base/base_theme_icon.dart';
import '../play/play_history_page.dart';
import '../play/play_list_page.dart';

/// 播放页面，包括播放列表、播放历史等
class PlayPage extends StatefulWidget {
  /// 构造
  const PlayPage({super.key});

  @override
  State<PlayPage> createState() => _PlayPageState();
}

/// 状态
class _PlayPageState extends State<PlayPage>
    with AutomaticKeepAliveClientMixin {
  /// tabIndex
  int tabIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TabView(
      currentIndex: tabIndex,
      closeButtonVisibility: CloseButtonVisibilityMode.never,
      tabWidthBehavior: TabWidthBehavior.sizeToContent,
      onChanged: (index) {
        tabIndex = index;
        setState(() {});
      },
      tabs: [
        Tab(
          text: const Text('播放列表'),
          icon: tabIndex == 0
              ? const BaseThemeIcon(FluentIcons.list)
              : const Icon(FluentIcons.list),
          body: const PlayListPage(),
          semanticLabel: '播放列表',
        ),
        Tab(
          text: const Text('播放历史'),
          icon: tabIndex == 1
              ? const BaseThemeIcon(FluentIcons.history)
              : const Icon(FluentIcons.history),
          body: const PlayHistoryPage(),
          semanticLabel: '播放历史',
        ),
      ],
    );
  }
}
