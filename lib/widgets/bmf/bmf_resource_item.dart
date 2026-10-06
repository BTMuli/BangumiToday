// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

// Project imports:
import '../../core/services/file_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../core/utils/playback_paths.dart';
import '../../store/bt_dir_download_state.dart';
import '../rss/anibt_tag_chip.dart';
import '../rss/rss_release_data.dart';

/// 抽屉与详情页共用的 RSS 单项，列表与操作状态由调用方管理。
class BmfRssItem extends StatelessWidget {
  const BmfRssItem({
    super.key,
    required this.release,
    required this.actions,
    this.backgroundColor,
    this.isPending = false,
    this.spacious = false,
  });

  final RssReleaseData release;
  final Widget actions;
  final Color? backgroundColor;
  final bool isPending;
  final bool spacious;

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    var publishedAt = release.publishedAt;
    return _ResourceItemSurface(
      backgroundColor: backgroundColor,
      spacious: spacious,
      highlighted: isPending,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (release.imageUrl != null)
                ClipRRect(
                  borderRadius: BTRadius.smallBR,
                  child: CachedNetworkImage(
                    imageUrl: release.imageUrl!,
                    width: 48,
                    height: 64,
                    fit: BoxFit.cover,
                    memCacheWidth: (48 * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                    placeholder: (_, _) =>
                        const SizedBox(width: 48, height: 64),
                    errorWidget: (_, _, _) =>
                        const Icon(FluentIcons.photo_error, size: 16),
                  ),
                )
              else
                Icon(
                  FluentIcons.download,
                  size: 16,
                  color: isPending ? accent : BTColors.textSecondary(context),
                ),
              const SizedBox(width: 8),
              if (isPending) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BTRadius.roundBR,
                  ),
                  child: const Text(
                    '新',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Tooltip(
                  message: release.title,
                  child: Text(
                    release.title,
                    style: BTTypography.body(context),
                    maxLines: spacious ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          if (release.metadataLabels.isNotEmpty) ...[
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var label in release.metadataLabels)
                    AnibtTagChip(label: label, maxWidth: constraints.maxWidth),
                ],
              ),
            ),
          ],
          if (release.summary != null) ...[
            const SizedBox(height: 6),
            Text(
              release.summary!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BTTypography.caption(context),
            ),
          ],
          SizedBox(height: spacious ? 8 : 4),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    if (release.sizeLabel != null)
                      Text(
                        release.sizeLabel!,
                        style: BTTypography.caption(context),
                      ),
                    if (publishedAt != null)
                      Text(
                        DateFormat(
                          'yyyy-MM-dd HH:mm',
                        ).format(publishedAt.toLocal()),
                        style: BTTypography.caption(context),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              actions,
            ],
          ),
        ],
      ),
    );
  }
}

/// 共用文件单项，下载进度来自引擎，播放及删除操作由调用方提供。
class BmfFileItem extends StatelessWidget {
  const BmfFileItem({
    super.key,
    required this.file,
    required this.actions,
    this.backgroundColor,
    this.fileSize,
    this.state,
    this.stateUnknown = false,
    this.spacious = false,
  });

  final String file;
  final Color? backgroundColor;
  final int? fileSize;
  final BtFileDownloadState? state;
  final bool stateUnknown;
  final bool spacious;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    var incomplete = state?.isIncomplete == true || stateUnknown;
    var statusColor = state?.isPaused == true
        ? BTColors.warningLight(context)
        : state?.isFailed == true
        ? BTColors.errorLight(context)
        : FluentTheme.of(context).accentColor;
    return _ResourceItemSurface(
      backgroundColor: backgroundColor,
      spacious: spacious,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                PlaybackPaths.isVideo(file)
                    ? FluentIcons.video
                    : FluentIcons.document,
                size: 16,
                color: incomplete
                    ? statusColor
                    : BTColors.textSecondary(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: file,
                  child: Text(
                    file,
                    style: BTTypography.body(context),
                    maxLines: spacious ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacious ? 8 : 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (fileSize != null)
                          Text(
                            BTFileTool.formatSize(fileSize!),
                            style: BTTypography.caption(context),
                          ),
                        if (incomplete)
                          Text(
                            stateUnknown
                                ? '下载状态待确认'
                                : state?.statusLabel ?? '下载中',
                            style: BTTypography.caption(
                              context,
                            ).copyWith(color: statusColor),
                          ),
                      ],
                    ),
                    if (state?.isIncomplete == true) ...[
                      const SizedBox(height: 6),
                      ProgressBar(
                        value: state?.progress == null
                            ? null
                            : state!.progress! * 100,
                        strokeWidth: 2,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              actions,
            ],
          ),
        ],
      ),
    );
  }
}

class _ResourceItemSurface extends StatelessWidget {
  const _ResourceItemSurface({
    required this.child,
    required this.spacious,
    this.backgroundColor,
    this.highlighted = false,
  });

  final Widget child;
  final Color? backgroundColor;
  final bool spacious;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    var surface = backgroundColor ?? BTColors.surfaceSecondary(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacious ? 12 : 10,
        vertical: spacious ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? Color.alphaBlend(accent.withValues(alpha: 0.12), surface)
            : surface,
        borderRadius: spacious ? BTRadius.mediumBR : BTRadius.smallBR,
        border: Border.all(
          color: highlighted ? accent : BTColors.divider(context),
        ),
      ),
      child: child,
    );
  }
}
