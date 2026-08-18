// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../widgets/common/bt_animations.dart';
import 'sd_pw_overview.dart';
import 'sdp_sections.dart';
import 'sdp_view_data.dart';

/// 当前条目详情布局（单列滚动）。
class SdpLayoutCurrent extends StatelessWidget {
  const SdpLayoutCurrent({super.key, required this.view});

  final SubjectDetailViewData view;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BTFadeSlideIn(
            duration: const Duration(milliseconds: 300),
            child: sdpSurfaceCard(
              context,
              SdpOverviewWidget(view.subject, onTagTap: view.onTagTap),
            ),
          ),
          SizedBox(height: 12),
          if (view.user != null)
            BTFadeSlideIn(
              duration: const Duration(milliseconds: 350),
              delay: const Duration(milliseconds: 50),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BTColors.surfaceSecondary(context),
                  borderRadius: BTRadius.mediumBR,
                ),
                child: Row(
                  children: [
                    Expanded(child: view.buildCollection()),
                    SizedBox(width: 12),
                    Tooltip(
                      message: '打开 BMF 配置',
                      child: IconButton(
                        icon: Icon(
                          FluentIcons.app_icon_default,
                          size: 18,
                          color: FluentTheme.of(context).accentColor,
                        ),
                        onPressed: view.openBmfDrawer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          BTFadeSlideIn(
            duration: const Duration(milliseconds: 400),
            delay: const Duration(milliseconds: 100),
            child: SdpSection(
              icon: FluentIcons.video,
              title: '剧集列表',
              initiallyExpanded: true,
              content: view.buildEpisodes(),
            ),
          ),
          BTFadeSlideIn(
            duration: const Duration(milliseconds: 450),
            delay: const Duration(milliseconds: 150),
            child: SdpSection(
              icon: FluentIcons.link,
              title: '关联条目',
              content: view.buildRelations(),
            ),
          ),
          BTFadeSlideIn(
            duration: const Duration(milliseconds: 500),
            delay: const Duration(milliseconds: 200),
            child: SdpSection(
              icon: FluentIcons.info,
              title: '简介',
              initiallyExpanded: true,
              content: SdpSummaryBody(view: view),
            ),
          ),
          BTFadeSlideIn(
            duration: const Duration(milliseconds: 550),
            delay: const Duration(milliseconds: 250),
            child: SdpSection(
              icon: FluentIcons.settings,
              title: '详细信息',
              content: SdpInfoboxBody(view: view),
            ),
          ),
        ],
      ),
    );
  }
}
