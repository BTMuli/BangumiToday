part of 'playback_page.dart';

/// Preparation remains visible when the normal playback chrome fades out.
class _PlaybackTensorRtProgress extends StatefulWidget {
  const _PlaybackTensorRtProgress({
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
  final _scroll = ScrollController();
  bool _details = true;

  @override
  void didUpdateWidget(covariant _PlaybackTensorRtProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow new lines only when the reader is already at the bottom. A reader
    // inspecting an earlier layer keeps their scroll position.
    if (!_scroll.hasClients || _scroll.position.extentAfter < 24) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _bytes(int value) => '${(value / 1048576).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    var resources = widget.store.tensorRtResources;
    var preparing = resources.native?.preparing == true;
    var missing = resources.native?.phase == 'resources_missing';
    var failed =
        resources.stage == 'failed' ||
        resources.stage == 'cancelled' ||
        resources.native?.phase == 'failed';
    return GestureDetector(
      onDoubleTap: () {},
      child: Container(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xED181818),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    resources.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                if (preparing || resources.lines.isNotEmpty)
                  material.TextButton(
                    onPressed: () => setState(() => _details = !_details),
                    child: Text(_details ? '收起细节' : '编译细节'),
                  ),
                if (resources.busy || preparing)
                  material.TextButton(
                    onPressed: () =>
                        unawaited(widget.run(widget.store.cancelTensorRt)),
                    child: const Text('取消'),
                  ),
                if (!resources.busy && (missing || failed))
                  material.TextButton(
                    onPressed: missing && !resources.canDownload
                        ? null
                        : () =>
                              unawaited(widget.run(widget.store.retryTensorRt)),
                    child: Text(missing ? '下载组件' : '重试'),
                  ),
              ],
            ),
            if (missing && !resources.busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  '下载约 329 MB · 安装约 611 MB · 首次按模型和分辨率编译',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            if (resources.busy || preparing) ...[
              const SizedBox(height: 6),
              material.LinearProgressIndicator(value: resources.progress),
              if (resources.progress != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${_bytes(resources.received)} / ${_bytes(resources.total)}'
                    ' · ${(resources.progress! * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
            if (_details && (preparing || resources.lines.isNotEmpty)) ...[
              const SizedBox(height: 8),
              Flexible(
                child: SizedBox(
                  height: 160,
                  child: resources.lines.isEmpty
                      ? const Text(
                          '正在校验组件或等待显卡，编译器启动后显示输出。',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        )
                      : material.Scrollbar(
                          controller: _scroll,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: _scroll,
                            itemCount: resources.lines.length,
                            itemBuilder: (_, index) => SelectableText(
                              resources.lines[index],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontFamily: 'Consolas',
                                height: 1.4,
                              ),
                            ),
                          ),
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
