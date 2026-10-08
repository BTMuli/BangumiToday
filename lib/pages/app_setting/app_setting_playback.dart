// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
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
      Future.microtask(
        () => mounted
            ? ref.read(playbackStoreProvider).tensorRtResources.initialize()
            : Future<void>.value(),
      ),
    );
  }

  String _bytes(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

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
    return BTSettingSection(
      icon: FluentIcons.video,
      title: '视频超分',
      subtitle: 'TensorRT · 安装与配置',
      children: [
        Text(
          '先检测显卡并安装组件，配置完成后在播放器中勾选“启用 TensorRT”。',
          style: FluentTheme.of(context).typography.body,
        ),
        const SizedBox(height: 12),
        ListTile(
          title: const Text('显卡与驱动'),
          subtitle: Text(resources.gpu?.label ?? '正在检测 NVIDIA 显卡…'),
          trailing: Button(
            onPressed: working
                ? null
                : () => unawaited(
                    resources.refresh(detectGpu: true, force: true),
                  ),
            child: const Text('重新检测'),
          ),
        ),
        const SizedBox(height: 8),
        InfoBar(
          title: Text(resources.configurationLabel),
          content: Text(
            '支持 NVIDIA SM89、SM90、SM100、SM120 显卡（最低 SM89），'
            '需要 CUDA 13.4 或更高版本驱动。'
            '${resources.total > 0 ? '当前显卡组件下载约 ${_bytes(resources.total)}，'
                      '安装约 ${_bytes(resources.installedBytes)}。' : ''}',
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
              style: FluentTheme.of(context).typography.caption,
            ),
          ],
          if (resources.preparingEngines) ...[
            const SizedBox(height: 6),
            Text(
              '${resources.completedEngines} / 4 个引擎已就绪',
              style: FluentTheme.of(context).typography.caption,
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
          style: FluentTheme.of(context).typography.caption,
        ),
        if (showDetails) ...[
          const SizedBox(height: 12),
          SizedBox(
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
