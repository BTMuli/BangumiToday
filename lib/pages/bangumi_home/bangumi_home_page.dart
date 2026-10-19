// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../models/bangumi/bangumi_subject_browse.dart';
import '../../widgets/common/bt_buttons.dart';
import '../bangumi_calendar/bangumi_calendar_page.dart';
import 'bangumi_ranking_page.dart';

/// 在同一首页中切换放送日历与排行榜。
class BangumiHomePage extends StatefulWidget {
  const BangumiHomePage({super.key});

  @override
  State<BangumiHomePage> createState() => _BangumiHomePageState();
}

class _BangumiHomePageState extends State<BangumiHomePage> {
  bool _showRanking = false;
  bool _rankingVisited = false;
  BangumiSubjectBrowseSort _rankingSort = BangumiSubjectBrowseSort.trends;

  void _toggleView() {
    setState(() {
      _showRanking = !_showRanking;
      if (_showRanking) _rankingVisited = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    var destination = _showRanking ? '放送日历' : '排行榜 · ${_rankingSort.label}';
    return Stack(
      fit: StackFit.expand,
      children: [
        IndexedStack(
          index: _showRanking ? 1 : 0,
          sizing: StackFit.expand,
          children: [
            TickerMode(
              enabled: !_showRanking,
              child: const BangumiCalendarPage(),
            ),
            TickerMode(
              enabled: _showRanking,
              child: _rankingVisited
                  ? BangumiRankingPage(
                      sort: _rankingSort,
                      onSortChanged: (sort) =>
                          setState(() => _rankingSort = sort),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: Semantics(
            label: '切换到$destination',
            button: true,
            child: BTFloatingActionButton(
              icon: _showRanking ? FluentIcons.calendar : _rankingSort.icon,
              tooltip: destination,
              onPressed: _toggleView,
            ),
          ),
        ),
      ],
    );
  }
}
