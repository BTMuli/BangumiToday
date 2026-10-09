part of 'playback_page.dart';

/// Only model preparation remains in playback; installation lives in Settings.
class _PlaybackTensorRtProgress extends StatefulWidget {
  const _PlaybackTensorRtProgress({
    super.key,
    required this.store,
    required this.run,
    required this.maxHeight,
  });
  final PlaybackStore store;
  final Future<void> Function(Future<void> Function()) run;
  final double maxHeight;

  @override
  State<_PlaybackTensorRtProgress> createState() =>
      _PlaybackTensorRtProgressState();
}

class _PlaybackTensorRtProgressState extends State<_PlaybackTensorRtProgress> {
  bool _details = true;
  bool _preparing = false;

  @override
  void initState() {
    super.initState();
    _preparing = widget.store.tensorRtResources.native?.preparing == true;
  }

  @override
  void didUpdateWidget(covariant _PlaybackTensorRtProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    var preparing = widget.store.tensorRtResources.native?.preparing == true;
    if (preparing && !_preparing) _details = true;
    _preparing = preparing;
  }

  @override
  Widget build(BuildContext context) {
    var resources = widget.store.tensorRtResources;
    var preparing = resources.native?.preparing == true;
    var missing = resources.native?.phase == 'resources_missing';
    var failed = resources.native?.phase == 'failed';
    var theme = FluentTheme.of(context);
    var showLog = _details || failed;
    var compact = widget.maxHeight < 150;
    return GestureDetector(
      onDoubleTap: () {},
      child: Container(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        padding: EdgeInsets.all(compact ? 8 : 12),
        decoration: BoxDecoration(
          color: theme.micaBackgroundColor.withValues(alpha: 0.72),
          border: Border.all(color: theme.resources.controlStrokeColorDefault),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    missing ? 'TensorRT 组件不可用，请在应用设置中重新安装' : resources.label,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.bodyStrong,
                  ),
                ),
                if (!preparing)
                  Tooltip(
                    message: '关闭编译提示',
                    child: IconButton(
                      icon: const Icon(FluentIcons.chrome_close, size: 12),
                      onPressed: resources.dismissBuildNotice,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (!failed && (preparing || resources.lines.isNotEmpty))
                  HyperlinkButton(
                    onPressed: () => setState(() => _details = !_details),
                    child: Text(_details ? '收起编译日志' : '查看编译日志'),
                  ),
                if (preparing)
                  Button(
                    onPressed: () =>
                        unawaited(widget.run(widget.store.cancelTensorRt)),
                    child: const Text('取消编译'),
                  ),
                if (failed && widget.store.tensorRtEnabled)
                  Button(
                    onPressed: () =>
                        unawaited(widget.run(widget.store.retryTensorRt)),
                    child: const Text('重试编译'),
                  ),
                if (failed || missing)
                  Button(
                    onPressed: () => unawaited(
                      widget.run(
                        () => widget.store.setUpscaleMode(
                          PlaybackUpscaleMode.off,
                        ),
                      ),
                    ),
                    child: const Text('关闭 AI 超分'),
                  ),
              ],
            ),
            if (preparing) ...[const SizedBox(height: 8), const ProgressBar()],
            if (showLog && (preparing || resources.lines.isNotEmpty)) ...[
              const SizedBox(height: 10),
              Flexible(
                child: SizedBox(
                  height: 160,
                  child: PlaybackBuildLog(
                    lines: resources.lines,
                    emptyText: '正在校验组件或等待显卡，编译器启动后显示输出。',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
