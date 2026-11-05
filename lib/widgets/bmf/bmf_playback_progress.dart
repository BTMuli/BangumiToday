// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../core/utils/subject_unwatched_local.dart';
import '../../data/repositories/episode_mark_gateway_impl.dart';
import '../../models/playback/playback_item.dart';
import '../../pages/playback/playback_actions.dart';
import '../../providers/bangumi_providers.dart';
import '../../providers/episode_mark_providers.dart';
import '../../providers/subject_playback_providers.dart';
import '../../ui/bt_icon.dart';
import '../playback/subject_continue_playback_button.dart';

/// BMF 详情头：继续播放。
class BmfSubjectPlaybackActions extends ConsumerStatefulWidget {
  const BmfSubjectPlaybackActions({super.key, required this.subject});

  final int subject;

  @override
  ConsumerState<BmfSubjectPlaybackActions> createState() =>
      _BmfSubjectPlaybackActionsState();
}

class _BmfSubjectPlaybackActionsState
    extends ConsumerState<BmfSubjectPlaybackActions> {
  String? _progressSignature;

  void _syncProgress(List<PlaybackItem> files) {
    var account = ref.read(episodeMarkProvider).account;
    var signature = (
      account,
      widget.subject,
      files.map((file) => file.key).join('\n'),
    ).toString();
    if (_progressSignature == signature) return;
    _progressSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _progressSignature != signature || files.isEmpty) {
        return;
      }
      unawaited(ref.read(episodeMarkProvider.notifier).syncItems(files));
    });
  }

  @override
  Widget build(BuildContext context) {
    var watched =
        ref
            .watch(bangumiLocalCollectionProvider(widget.subject))
            .value
            ?.epStatus ??
        0;
    var files =
        ref.watch(subjectPlaybackFilesProvider(widget.subject)).value ??
        const <PlaybackItem>[];
    _syncProgress(files);
    return SubjectContinuePlaybackButton(
      key: ValueKey(widget.subject),
      subject: widget.subject,
      watchedEpisodes: watched,
    );
  }
}

/// 列表行内的未看计数与续播；不依赖先选中详情。
class BmfListPlaybackStrip extends ConsumerStatefulWidget {
  const BmfListPlaybackStrip({super.key, required this.subject});

  final int subject;

  @override
  ConsumerState<BmfListPlaybackStrip> createState() =>
      _BmfListPlaybackStripState();
}

class _BmfListPlaybackStripState extends ConsumerState<BmfListPlaybackStrip> {
  String? _progressSignature;

  void _syncProgress(List<PlaybackItem> files) {
    var account = ref.read(episodeMarkProvider).account;
    var signature = (
      account,
      widget.subject,
      files.map((file) => file.key).join('\n'),
    ).toString();
    if (_progressSignature == signature) return;
    _progressSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _progressSignature != signature || files.isEmpty) {
        return;
      }
      unawaited(ref.read(episodeMarkProvider.notifier).syncItems(files));
    });
  }

  @override
  Widget build(BuildContext context) {
    var watched =
        ref
            .watch(bangumiLocalCollectionProvider(widget.subject))
            .value
            ?.epStatus ??
        0;
    var files =
        ref.watch(subjectPlaybackFilesProvider(widget.subject)).value ??
        const <PlaybackItem>[];
    _syncProgress(files);
    var unwatched = ref
        .watch(
          subjectUnwatchedLocalEpisodesProvider((
            subject: widget.subject,
            watchedEpisodes: watched,
          )),
        )
        .value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (unwatched != null && unwatched.isNotEmpty)
          BmfUnwatchedCountFlyout(subject: widget.subject, episodes: unwatched),
        SubjectContinuePlaybackButton(
          key: ValueKey(widget.subject),
          subject: widget.subject,
          watchedEpisodes: watched,
          compact: true,
        ),
      ],
    );
  }
}

/// 未看计数触发器；点击后在 flyout 中列出可直接播放的集数。
class BmfUnwatchedCountFlyout extends ConsumerStatefulWidget {
  const BmfUnwatchedCountFlyout({
    super.key,
    required this.subject,
    required this.episodes,
  });

  final int subject;
  final List<UnwatchedLocalEpisode> episodes;

  @override
  ConsumerState<BmfUnwatchedCountFlyout> createState() =>
      _BmfUnwatchedCountFlyoutState();
}

class _BmfUnwatchedCountFlyoutState
    extends ConsumerState<BmfUnwatchedCountFlyout> {
  static const _gap = 6.0;

  final FlyoutController _controller = FlyoutController();
  final GlobalKey _targetKey = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openFlyout() async {
    var box = _targetKey.currentContext?.findRenderObject() as RenderBox?;
    var overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    var placement = FlyoutPlacementMode.bottomLeft;
    if (box != null && overlay is RenderBox) {
      var topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
      var below = overlay.size.height - (topLeft.dy + box.size.height) - _gap;
      var above = topLeft.dy - _gap;
      var desired = (widget.episodes.length * 36.0).clamp(72.0, 320.0);
      if (below < desired && above > below) {
        placement = FlyoutPlacementMode.topLeft;
      }
    }
    await _controller.showFlyout<void>(
      placementMode: placement,
      additionalOffset: _gap,
      barrierDismissible: true,
      dismissWithEsc: true,
      builder: (flyoutContext) => MenuFlyout(
        items: [
          for (var episode in widget.episodes)
            MenuFlyoutItem(
              leading: const BtIcon(FluentIcons.play, size: 14),
              text: Text('第 ${episode.label} 集'),
              onPressed: () {
                unawaited(
                  openLocalPlayback(
                    context,
                    ref,
                    episode.filePath,
                    subject: widget.subject,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var label = formatUnwatchedEpisodeSummary(widget.episodes);
    if (label.isEmpty) return const SizedBox.shrink();
    var accent = FluentTheme.of(context).accentColor;
    return FlyoutTarget(
      key: _targetKey,
      controller: _controller,
      child: Tooltip(
        message: '查看未看集数并播放',
        child: HoverButton(
          onPressed: _openFlyout,
          builder: (context, states) => Text(
            label,
            style: BTTypography.caption(
              context,
            ).copyWith(color: accent, height: 1),
          ),
        ),
      ),
    );
  }
}

/// 本地文件行的观看状态字幕。
class BmfFilePlaybackSubtitle extends ConsumerWidget {
  const BmfFilePlaybackSubtitle({
    super.key,
    required this.subject,
    required this.dir,
    required this.file,
  });

  final int subject;
  final String dir;
  final String file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var filePath = path.join(dir, file);
    var key = PlaybackItem.pathKey(filePath);
    var watched =
        ref.watch(bangumiLocalCollectionProvider(subject)).value?.epStatus ?? 0;
    var local = ref.watch(subjectPlaybackByPathProvider(subject)).value?[key];
    var links = ref.watch(subjectEpisodeFilesProvider(subject)).value;
    var chapters = ref.watch(subjectFileEpisodesProvider(subject)).value;
    var progress = ref.watch(subjectEpisodeProgressProvider(subject));
    String? status;
    if (links != null && chapters != null) {
      var link = links.where((item) => item.key == key).firstOrNull;
      if (link != null && !link.excluded && link.episode != null) {
        var chapter = chapters
            .where((item) => item.id == link.episode)
            .map(episodeMarkChapter)
            .map(
              (item) => progress[item.id] == null
                  ? item
                  : item.withDone(progress[item.id]!),
            )
            .firstOrNull;
        if (chapter != null) {
          var number = subjectEpisodeNumberLabel(chapter);
          if (isSubjectEpisodeWatched(
            chapter,
            watchedEpisodes: watched,
            local: local,
          )) {
            status = local != null && !local.completed
                ? '第 $number 集 · ${_formatProgress(local)}'
                : '已看 · 第 $number 集';
          } else {
            status = local == null
                ? '未看 · 第 $number 集'
                : '未看 · 第 $number 集 · ${_formatProgress(local)}';
          }
        }
      }
    }
    status ??= local == null
        ? null
        : local.completed
        ? '已播完'
        : _formatProgress(local);
    if (status == null) return const SizedBox.shrink();
    var accent = status.startsWith('未看');
    return Text(
      status,
      style: BTTypography.caption(
        context,
      ).copyWith(color: accent ? FluentTheme.of(context).accentColor : null),
    );
  }
}

String _formatProgress(PlaybackItem item) {
  if (item.completed) return '已播完';
  if (item.durationMs > 0) {
    return '${_formatMs(item.positionMs)} / ${_formatMs(item.durationMs)}';
  }
  return _formatMs(item.positionMs);
}

String _formatMs(int milliseconds) {
  var value = Duration(milliseconds: milliseconds);
  var hours = value.inHours;
  var minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
  var seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
