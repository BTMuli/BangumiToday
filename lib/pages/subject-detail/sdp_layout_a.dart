// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/layout/responsive.dart';
import '../../models/bangumi/bangumi_enum.dart';
import 'sdp_action_bar.dart';
import 'sdp_identity_band.dart';
import 'sdp_score_section.dart';
import 'sdp_sections.dart';
import 'sdp_view_data.dart';

/// 方案 A：身份带 + 操作条 + 按状态展开一节。
class SdpLayoutA extends StatelessWidget {
  const SdpLayoutA({super.key, required this.view, this.hasBmf});

  final SubjectDetailViewData view;
  final bool? hasBmf;

  @override
  Widget build(BuildContext context) {
    if (hasBmf != null) return _buildBody(context, hasBmf!);
    return SdpBmfStatusBar(
      subjectId: view.subject.id,
      child: (configured) => _buildBody(context, configured),
    );
  }

  bool _watching(bool configured) {
    var collected = view.collectProvider.collected;
    var doing = view.collectProvider.type == BangumiCollectionType.doing;
    return (collected && doing) || configured;
  }

  Widget _buildBody(BuildContext context, bool configured) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var watching = _watching(configured);
        var split = constraints.maxWidth >= BTBreakpoints.desktop;
        var identity = sdpSurfaceCard(
          context,
          SdpIdentityBand(subject: view.subject, onTagTap: view.onTagTap),
        );
        var actions = SdpActionBar(view: view, hasBmf: configured);
        var sections = _buildSections(watching);
        if (!split) {
          return SingleChildScrollView(
            key: const ValueKey('subject-layout-a'),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                SizedBox(height: 12),
                actions,
                SizedBox(height: 12),
                ...sections,
              ],
            ),
          );
        }
        var leftWidth = (constraints.maxWidth * 0.52).clamp(520.0, 720.0);
        return Row(
          key: const ValueKey('subject-layout-a'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: leftWidth,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 16, 8, 16),
                child: Column(
                  children: [identity, SizedBox(height: 12), actions],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(8, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sections,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildSections(bool watching) {
    return [
      SdpSection(
        icon: FluentIcons.info,
        title: '简介',
        initiallyExpanded: !watching,
        content: SdpSummaryBody(view: view),
      ),
      SdpSection(
        icon: FluentIcons.video,
        title: '剧集进度',
        initiallyExpanded: watching,
        content: view.buildEpisodes(showSummary: true, showGrid: false),
      ),
      SdpScoreHeatExpander(subject: view.subject),
      SdpSection(
        icon: FluentIcons.link,
        title: '关联条目',
        content: view.buildRelations(),
      ),
      SdpSection(
        icon: FluentIcons.settings,
        title: '详细信息',
        content: SdpInfoboxBody(view: view),
      ),
    ];
  }
}
