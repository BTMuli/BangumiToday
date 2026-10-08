// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

// Project imports:
import '../../core/services/playback_tensorrt_gpu.dart';
import '../../core/theme/bt_theme.dart';
import '../../models/playback/playback_janai_benchmark.dart';
import '../../models/playback/playback_upscale.dart';
import '../../store/playback_store.dart';
import '../../widgets/common/bt_setting_section.dart';
import '../../widgets/playback/playback_build_log.dart';

class AppConfigPlaybackWidget extends ConsumerStatefulWidget {
  const AppConfigPlaybackWidget({super.key});

  @override
  ConsumerState<AppConfigPlaybackWidget> createState() =>
      _AppConfigPlaybackWidgetState();
}

class _AppConfigPlaybackWidgetState
    extends ConsumerState<AppConfigPlaybackWidget> {
  bool? _details;

  @override
  void initState() {
    super.initState();
    // The store owns installation; leaving Settings does not cancel it.
    unawaited(
      Future.microtask(() async {
        if (!mounted) return;
        var store = ref.read(playbackStoreProvider);
        await Future.wait([
          store.tensorRtResources.initialize(),
          store.janaiBenchmarks.initialize(),
        ]);
      }),
    );
  }

  String _bytes(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

  Widget _heading(String title, {String? subtitle, Widget? action}) {
    var label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: BTTypography.bodyStrong(context)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: BTTypography.caption(context)),
        ],
      ],
    );
    if (action == null) return label;
    return LayoutBuilder(
      builder: (_, constraints) => constraints.maxWidth >= 600
          ? Row(
              children: [
                Expanded(child: label),
                const SizedBox(width: 16),
                action,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 10), action],
            ),
    );
  }

  Widget _panel(Widget child, {bool recommended = false}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: BTColors.surfaceSecondary(context).withValues(alpha: 0.65),
      borderRadius: BTRadius.mediumBR,
      border: Border.all(
        color: recommended
            ? FluentTheme.of(context).accentColor.withValues(alpha: 0.3)
            : BTColors.divider(context),
      ),
    ),
    child: child,
  );

  Widget _recommendationCard(
    int height,
    PlaybackJanaiRecommendation recommendation,
  ) => _panel(
    recommended: recommendation.mode != null,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${height}p', style: BTTypography.subtitle(context)),
            ),
            Text('24 fps 片源', style: BTTypography.caption(context)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          recommendation.label,
          style: BTTypography.subtitle(context).copyWith(
            color: recommendation.mode != null
                ? FluentTheme.of(context).accentColor
                : BTColors.textSecondary(context),
          ),
        ),
        if (recommendation.estimates.isNotEmpty) ...[
          const BTSettingDivider(),
          for (var mode in [
            PlaybackUpscaleMode.janaiSmooth,
            PlaybackUpscaleMode.janaiQuality,
          ])
            if (recommendation.estimates.containsKey(mode))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: BTTypography.bodyStrong(
                        context,
                      ).copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      recommendation.description(mode),
                      style: BTTypography.caption(
                        context,
                      ).copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
        ],
      ],
    ),
  );

  Widget _benchmarks(PlaybackStore store) {
    var benchmarks = store.janaiBenchmarks;
    var catalog = benchmarks.catalog;
    var gpu = store.tensorRtResources.gpu;
    var updated = catalog?.generatedAt.toLocal().toIso8601String().substring(
      0,
      10,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          '推荐档位',
          subtitle: 'AnimeJaNai 社区基准 · 根据当前显卡匹配',
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              HyperlinkButton(
                onPressed: () => unawaited(
                  launchUrl(Uri.parse(PlaybackJanaiBenchmarkCatalog.url)),
                ),
                child: const Text('查看基准目录'),
              ),
              Button(
                onPressed: benchmarks.updating
                    ? null
                    : () => unawaited(benchmarks.refresh()),
                child: Text(benchmarks.updating ? '正在更新…' : '更新数据'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (catalog == null)
          Text(
            benchmarks.error ?? '正在读取基准数据…',
            style: BTTypography.caption(context),
          )
        else if (gpu == null)
          Text('等待检测显卡', style: BTTypography.caption(context))
        else if (!gpu.supported)
          Text(gpu.requirement, style: BTTypography.caption(context))
        else
          LayoutBuilder(
            builder: (_, constraints) {
              var width = constraints.maxWidth >= 680
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var (sourceWidth, height) in [(1280, 720), (1920, 1080)])
                    SizedBox(
                      width: width,
                      child: _recommendationCard(
                        height,
                        catalog.recommend(
                          gpu: gpu.name,
                          width: sourceWidth,
                          height: height,
                          fps: 24,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 12),
        Text(
          '同型号最低实测值，预留两倍帧率余量。'
          '离屏基准仅供参考，播放器会按片源与倍速重新推荐。',
          style: BTTypography.caption(context).copyWith(height: 1.5),
        ),
        if (catalog != null) ...[
          const SizedBox(height: 4),
          Text('数据更新于 $updated', style: BTTypography.caption(context)),
        ],
        if (catalog != null && benchmarks.error != null) ...[
          const SizedBox(height: 8),
          Text(
            benchmarks.error!,
            style: BTTypography.caption(
              context,
            ).copyWith(color: BTColors.warningLight(context)),
          ),
        ],
      ],
    );
  }

  Widget _sizeLabel(String label, int bytes) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: BTTypography.caption(context)),
      const SizedBox(height: 4),
      Text(_bytes(bytes), style: BTTypography.bodyStrong(context)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    var store = ref.watch(playbackStoreProvider);
    var resources = store.tensorRtResources;
    var failed = resources.stage == 'failed';
    var retry = failed || resources.stage == 'cancelled';
    var working = resources.busy || resources.checking;
    var progress = resources.progress;
    var enginesReady = resources.completedEngines == 4 && !retry;
    var showDetails = _details ?? (resources.preparingEngines || failed);
    var gpu = resources.gpu;
    var architectures = (PlaybackTensorRtGpu.supportedSm.toList()..sort())
        .map((sm) => 'SM$sm')
        .join(' / ');
    return BTSettingSection(
      icon: FluentIcons.video,
      title: '视频超分',
      subtitle: 'TensorRT · 安装与配置',
      children: [
        Text(
          '配置显卡组件后，可在播放器中启用 TensorRT 并选择 AI 超分档位。',
          style: BTTypography.body(
            context,
          ).copyWith(color: BTColors.textSecondary(context), height: 1.5),
        ),
        const SizedBox(height: 20),
        _heading(
          '显卡与驱动',
          action: Button(
            onPressed: working
                ? null
                : () => unawaited(
                    resources.refresh(detectGpu: true, force: true),
                  ),
            child: const Text('重新检测'),
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gpu == null
                    ? '正在检测 NVIDIA 显卡…'
                    : gpu.error.isNotEmpty
                    ? gpu.error
                    : gpu.name,
                style: BTTypography.bodyStrong(context),
              ),
              if (gpu != null && gpu.error.isEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '计算架构 SM${gpu.sm} · 驱动支持 CUDA ${gpu.driverLabel}',
                  style: BTTypography.caption(context),
                ),
              ],
            ],
          ),
        ),
        const BTSettingDivider(),
        _benchmarks(store),
        const BTSettingDivider(),
        _heading(
          '组件与引擎',
          subtitle: '支持 NVIDIA $architectures，需 CUDA 13.4 或更高版本驱动',
        ),
        const SizedBox(height: 12),
        InfoBar(
          title: Text(
            resources.configurationLabel,
            style: BTTypography.bodyStrong(context),
          ),
          severity: failed
              ? InfoBarSeverity.error
              : resources.ready
              ? InfoBarSeverity.success
              : resources.gpu != null && !resources.canDownload
              ? InfoBarSeverity.warning
              : InfoBarSeverity.info,
          isLong: true,
        ),
        if (resources.total > 0) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 32,
            runSpacing: 12,
            children: [
              _sizeLabel('组件下载', resources.total),
              _sizeLabel('安装占用', resources.installedBytes),
            ],
          ),
        ],
        if (working) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ProgressBar(value: progress == null ? null : progress * 100),
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            Text(
              '${_bytes(resources.received)} / ${_bytes(resources.total)}'
              ' · ${(progress * 100).toStringAsFixed(1)}%',
              style: BTTypography.caption(context),
            ),
          ],
          if (resources.preparingEngines) ...[
            const SizedBox(height: 6),
            Text(
              '${resources.completedEngines} / 4 个引擎已就绪',
              style: BTTypography.caption(context),
            ),
          ],
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              onPressed: working || !resources.canDownload || enginesReady
                  ? null
                  : () => unawaited(store.downloadTensorRt()),
              child: Text(
                enginesReady
                    ? '引擎已就绪'
                    : resources.installed
                    ? retry
                          ? '继续准备引擎'
                          : '预编译常用引擎'
                    : retry
                    ? '重试安装'
                    : '下载并准备引擎',
              ),
            ),
            if (resources.busy)
              Button(onPressed: resources.cancel, child: const Text('取消')),
            if (resources.installationLines.isNotEmpty)
              HyperlinkButton(
                onPressed: () => setState(() => _details = !showDetails),
                child: Text(showDetails ? '收起准备日志' : '查看准备日志'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '组件安装后依次准备 720p、1080p × AI 流畅、AI 高质量，共四个引擎。'
          '已缓存的引擎直接复用，其他输入尺寸首次播放时按需编译。',
          style: BTTypography.caption(context).copyWith(height: 1.5),
        ),
        if (showDetails) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 180,
            child: PlaybackBuildLog(
              lines: [
                ...resources.installationLines,
                ...resources.precompileLines,
              ],
              emptyText: '等待准备任务输出…',
            ),
          ),
        ],
      ],
    );
  }
}
