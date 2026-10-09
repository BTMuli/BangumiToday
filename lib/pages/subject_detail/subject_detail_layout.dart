// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import 'subject_detail_colors.dart';
import 'subject_detail_overview.dart';
import 'subject_detail_sections.dart';
import 'subject_detail_view_data.dart';

enum _DetailTab {
  episodes('剧集'),
  resources('下载与订阅'),
  summary('简介'),
  infobox('详细信息'),
  characters('角色'),
  persons('制作人员'),
  relations('关联条目'),
  comments('吐槽');

  const _DetailTab(this.label);

  final String label;
}

/// 紧凑概览与详情页签，正文填满页面的实际剩余高度。
class SubjectDetailLayout extends StatefulWidget {
  const SubjectDetailLayout({
    super.key,
    required this.view,
    required this.resources,
    required this.onRefreshRelations,
  });

  final SubjectDetailViewData view;
  final Widget resources;
  final Future<void> Function() onRefreshRelations;

  @override
  State<SubjectDetailLayout> createState() => _SubjectDetailLayoutState();
}

class _SubjectDetailLayoutState extends State<SubjectDetailLayout> {
  // 独立接口只在对应页签首次被选中时挂载并请求。
  final Set<_DetailTab> _visited = {_DetailTab.episodes};
  _DetailTab _selected = _DetailTab.episodes;
  int? _relationCount;
  bool _refreshingRelations = false;

  void _select(_DetailTab tab) {
    setState(() {
      _selected = tab;
      _visited.add(tab);
    });
  }

  void _onRelationCountChanged(int count) {
    if (!mounted || _relationCount == count) return;
    setState(() => _relationCount = count);
  }

  Future<void> _refreshRelations() async {
    if (_refreshingRelations) return;
    setState(() => _refreshingRelations = true);
    try {
      await widget.onRefreshRelations();
    } finally {
      if (mounted) setState(() => _refreshingRelations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 极矮窗口或超长标题可滚动概览，普通窗口不产生外层滚动。
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.6,
              ),
              child: SingleChildScrollView(
                primary: false,
                child: SubjectDetailOverview(
                  view: widget.view,
                  onShowEpisodes: () => _select(_DetailTab.episodes),
                  tabBar: _buildTabs(context),
                ),
              ),
            ),
            // 页签行是页头最后一行，只留窄间距，使其紧贴内容容器上边。
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: SubjectDetailColors.content(context),
                  borderRadius: BTRadius.mediumBR,
                  border: Border.all(color: BTColors.divider(context)),
                ),
                child: IndexedStack(
                  index: _selected.index,
                  sizing: StackFit.expand,
                  children: [
                    for (var tab in _DetailTab.values)
                      KeyedSubtree(
                        key: ValueKey(tab),
                        child: TickerMode(
                          enabled: _selected == tab,
                          child: _buildTabBody(context, tab),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 页签条是页头最后一行，宽度自适应窗口并允许换行。
  Widget _buildTabs(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var tab in _DetailTab.values)
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _selected == tab ? accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Semantics(
              selected: _selected == tab,
              child: HyperlinkButton(
                key: ValueKey('subject-tab-${tab.name}'),
                onPressed: () => _select(tab),
                child: Text(
                  tab == _DetailTab.relations && _relationCount != null
                      ? '${tab.label} · $_relationCount'
                      : tab.label,
                  style: BTTypography.body(context).copyWith(
                    color: _selected == tab
                        ? BTColors.textPrimary(context)
                        : BTColors.textSecondary(context),
                    fontWeight: _selected == tab
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        if (_selected == _DetailTab.relations)
          Tooltip(
            message: '刷新关联条目',
            child: IconButton(
              icon: _refreshingRelations
                  ? const SizedBox.square(
                      dimension: 14,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  : const Icon(FluentIcons.refresh, size: 14),
              onPressed: _refreshingRelations ? null : _refreshRelations,
            ),
          ),
      ],
    );
  }

  Widget _buildTabBody(BuildContext context, _DetailTab tab) {
    if (!_visited.contains(tab)) return const SizedBox.shrink();
    if (tab == _DetailTab.resources) return widget.resources;
    var view = widget.view;
    if (tab == _DetailTab.characters) return view.buildCharacters();
    if (tab == _DetailTab.persons) return view.buildPersons();
    if (tab == _DetailTab.comments) return view.buildComments();
    return SingleChildScrollView(
      key: PageStorageKey('subject-${view.subject.id}-${tab.name}'),
      primary: false,
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: switch (tab) {
          _DetailTab.episodes => view.buildEpisodes(showSummary: true),
          _DetailTab.summary => SubjectDetailSummaryBody(view: view),
          _DetailTab.infobox => SubjectDetailInfoboxBody(view: view),
          _DetailTab.relations => view.buildRelations(
            onCountChanged: _onRelationCountChanged,
          ),
          _DetailTab.resources ||
          _DetailTab.characters ||
          _DetailTab.persons ||
          _DetailTab.comments => const SizedBox.shrink(),
        },
      ),
    );
  }
}
