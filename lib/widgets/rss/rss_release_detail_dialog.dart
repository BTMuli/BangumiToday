// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import 'anibt_tag_chip.dart';
import 'rss_release_data.dart';
import 'rss_release_description.dart';

/// 按来源解析 Markdown / HTML 描述，操作保持在弹窗底部。
class RssReleaseDetailDialog extends StatelessWidget {
  final RssReleaseData release;
  final Future<bool> Function(String url) onTapUrl;
  final Widget actions;
  final Uri? baseUrl;
  final bool markdownDescription;

  const RssReleaseDetailDialog({
    super.key,
    required this.release,
    required this.onTapUrl,
    required this.actions,
    this.baseUrl,
    this.markdownDescription = false,
  });

  @override
  Widget build(BuildContext context) {
    var description = rssDescriptionHtml(
      release.item.description,
      isMarkdown: markdownDescription,
    );
    var timestamp = release.publishedAt == null
        ? null
        : DateFormat('yyyy-MM-dd HH:mm').format(release.publishedAt!.toLocal());
    var metadata = [
      ...release.metadataLabels,
      if (release.sizeLabel != null) release.sizeLabel!,
      if (timestamp != null) '发布于 $timestamp',
    ];
    var accentHex = FluentTheme.of(
      context,
    ).accentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    return ContentDialog(
      constraints: BoxConstraints(
        maxWidth: 860,
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            release.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: BTTypography.subtitle(context),
          ),
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var label in metadata)
                  AnibtTagChip(label: label, maxWidth: 280),
              ],
            ),
          ],
        ],
      ),
      content: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: BTColors.surfaceSecondary(context),
          borderRadius: BTRadius.mediumBR,
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description == null || description.isEmpty)
                Text('该资源未提供详细介绍', style: BTTypography.body(context))
              else
                HtmlWidget(
                  description,
                  baseUrl:
                      baseUrl ??
                      Uri.tryParse(release.detailUrl ?? 'https://comicat.org'),
                  textStyle: BTTypography.body(context),
                  onTapUrl: onTapUrl,
                  customWidgetBuilder: (element) {
                    if (element.localName != 'pre') return null;
                    return _RssReleaseCodeBlock(
                      text: rssPreformattedText(element),
                    );
                  },
                  customStylesBuilder: (element) {
                    if (element.localName == 'a') {
                      return {'color': '#$accentHex'};
                    }
                    if (element.localName == 'strong' ||
                        element.localName == 'b') {
                      return {'font-weight': '700'};
                    }
                    if (element.localName == 'summary') {
                      return {'font-weight': '600', 'padding': '8px 0'};
                    }
                    if (element.localName == 'img') {
                      return {'max-width': '100%', 'height': 'auto'};
                    }
                    if (element.localName == 'pre') {
                      return {'white-space': 'pre'};
                    }
                    return null;
                  },
                  onErrorBuilder: (context, element, error) =>
                      Text('无法加载这部分内容', style: BTTypography.caption(context)),
                ),
            ],
          ),
        ),
      ),
      actions: [actions],
    );
  }
}

/// 折叠的 MediaInfo 与普通代码块使用独立的双向滚动区域。
class _RssReleaseCodeBlock extends StatefulWidget {
  final String text;

  const _RssReleaseCodeBlock({required this.text});

  @override
  State<_RssReleaseCodeBlock> createState() => _RssReleaseCodeBlockState();
}

class _RssReleaseCodeBlockState extends State<_RssReleaseCodeBlock> {
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: (MediaQuery.sizeOf(context).height * 0.35).clamp(
          120.0,
          320.0,
        ),
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BTColors.surfaceTertiary(context),
        borderRadius: BTRadius.smallBR,
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Scrollbar(
          controller: _verticalController,
          interactive: true,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.vertical,
          child: Scrollbar(
            controller: _horizontalController,
            interactive: true,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _verticalController,
              primary: false,
              child: SingleChildScrollView(
                controller: _horizontalController,
                primary: false,
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 12),
                  child: Text(
                    widget.text,
                    softWrap: false,
                    style: BTTypography.body(context).copyWith(
                      fontFamily: 'Consolas',
                      fontFamilyFallback: const ['monospace'],
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
