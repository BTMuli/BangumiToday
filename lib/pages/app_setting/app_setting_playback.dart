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
  bool _details = false;

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
          content: const Text(
            '仅支持 NVIDIA SM89 显卡和 CUDA 13.4 或更高版本驱动。'
            '组件下载约 329 MB，安装约 611 MB。',
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
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              onPressed:
                  working || !resources.canDownload || resources.installed
                  ? null
                  : () => unawaited(store.downloadTensorRt()),
              child: Text(
                resources.installed
                    ? '组件已安装'
                    : retry
                    ? '重试安装'
                    : '下载并安装组件',
              ),
            ),
            if (resources.busy)
              Button(onPressed: resources.cancel, child: const Text('取消')),
            if (resources.installationLines.isNotEmpty)
              HyperlinkButton(
                onPressed: () => setState(() => _details = !_details),
                child: Text(_details ? '收起安装日志' : '查看安装日志'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '首次使用 AI 模式时，会按模型和视频分辨率编译引擎，'
          '编译期间保持普通播放；已编译的结果会缓存复用。',
          style: FluentTheme.of(context).typography.caption,
        ),
        if (_details) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: PlaybackBuildLog(
              lines: resources.installationLines,
              emptyText: '等待安装任务输出…',
            ),
          ),
        ],
      ],
    );
  }
}
