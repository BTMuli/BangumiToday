// Dart imports:
import 'dart:async';

// Package imports:
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../core/services/playback_tensorrt_resources.dart';
import '../../core/services/playback_video_export.dart';
import '../../models/playback/playback_export.dart';
import '../../models/playback/playback_upscale.dart';
import '../../ui/bt_select.dart';

class PlaybackExportDialog extends StatefulWidget {
  const PlaybackExportDialog({
    super.key,
    required this.source,
    required this.video,
    required this.fps,
    required this.duration,
    required this.initialMode,
    required this.resources,
  });

  final String source;
  final PlaybackVideoSource video;
  final double fps;
  final Duration duration;
  final PlaybackUpscaleMode initialMode;
  final PlaybackTensorRtResources resources;

  @override
  State<PlaybackExportDialog> createState() => _PlaybackExportDialogState();
}

class _PlaybackExportDialogState extends State<PlaybackExportDialog> {
  final _export = PlaybackVideoExport();
  final _destination = TextEditingController();
  late PlaybackUpscaleMode _mode;
  bool _running = false;
  bool _cancelling = false;
  bool _complete = false;
  bool _picking = false;
  double _seconds = 0;
  String? _error;

  String get _sourceExtension => path.extension(widget.source).toLowerCase();
  PlaybackExportFormat get _format =>
      PlaybackExportFormat.fromExtension(
        path.extension(_destination.text).isEmpty
            ? _sourceExtension
            : path.extension(_destination.text),
      ) ??
      PlaybackExportFormat.mkv;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode == PlaybackUpscaleMode.off
        ? PlaybackUpscaleMode.standard
        : widget.initialMode;
  }

  @override
  void dispose() {
    _export.cancel();
    _destination.dispose();
    super.dispose();
  }

  String? _unavailable(PlaybackUpscaleMode mode) {
    if (mode.isJanai && !widget.resources.canEnable) {
      return '请先在应用设置中安装 TensorRT 组件';
    }
    try {
      playbackExportSize(widget.video, mode);
      return null;
    } catch (error) {
      return '$error';
    }
  }

  Future<void> _pickDestination() async {
    setState(() => _picking = true);
    try {
      var extension =
          PlaybackExportFormat.fromExtension(_sourceExtension) == null
          ? '.mkv'
          : _sourceExtension;
      var result = await getSaveLocation(
        initialDirectory: path.dirname(widget.source),
        suggestedName:
            '${path.basenameWithoutExtension(widget.source)}'
            '_${_mode.name}$extension',
        acceptedTypeGroups: [
          for (var format in [
            _format,
            ...PlaybackExportFormat.values.where((format) => format != _format),
          ])
            XTypeGroup(
              label: '${format.label} 视频',
              extensions: format.extensions,
            ),
        ],
        confirmButtonText: '选择保存位置',
      );
      if (!mounted || result == null) return;
      setState(() {
        _destination.text = path.extension(result.path).isEmpty
            ? '${result.path}.${_format.extensions.first}'
            : result.path;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _error = null;
      _seconds = 0;
    });
    try {
      var completed = await _export.run(
        source: widget.source,
        destination: _destination.text,
        video: widget.video,
        mode: _mode,
        fps: widget.fps,
        resources: widget.resources,
        onProgress: (seconds) {
          if (mounted) setState(() => _seconds = seconds);
        },
      );
      if (!mounted) return;
      if (!completed) {
        setState(() => _running = false);
        Navigator.of(context).pop();
        return;
      }
      setState(() => _complete = true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var unavailable = _unavailable(_mode);
    var total = widget.duration.inMilliseconds / 1000;
    var percent = total > 0 ? (_seconds / total * 100).clamp(0.0, 99.9) : null;
    var percentLabel = percent == null
        ? ''
        : ' · ${percent.toStringAsFixed(1)}%';
    PlaybackPixels? size;
    if (unavailable == null) size = playbackExportSize(widget.video, _mode);
    return PopScope(
      canPop: !_running,
      child: ContentDialog(
        constraints: const BoxConstraints(maxWidth: 540),
        title: const Text('导出超分视频'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(path.basename(widget.source)),
              const SizedBox(height: 16),
              const Text('超分档位'),
              const SizedBox(height: 6),
              BtSelect<PlaybackUpscaleMode>(
                value: _mode,
                isExpanded: true,
                items: [
                  for (var mode in PlaybackUpscaleMode.values)
                    if (mode != PlaybackUpscaleMode.off)
                      ComboBoxItem(
                        value: mode,
                        child: Text(
                          '${mode.isJanai ? 'JaNai' : 'Anime4K'}'
                          ' · ${mode.label}',
                        ),
                      ),
                ],
                onChanged: _running || _complete
                    ? null
                    : (mode) {
                        if (mode != null) setState(() => _mode = mode);
                      },
              ),
              const SizedBox(height: 8),
              Text(
                unavailable ??
                    '${size!.width} × ${size.height} · '
                        '${widget.fps.toStringAsFixed(3)} fps · '
                        '${_format.label} / ${_format.codecs}',
              ),
              const SizedBox(height: 6),
              const Text('导出完整视频，保留默认音轨，不烧录字幕。'),
              if (PlaybackExportFormat.fromExtension(_sourceExtension) == null)
                const Text('源视频封装暂不支持导出，默认使用 MKV。'),
              const SizedBox(height: 16),
              const Text('目标目录与文件名'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextBox(
                      controller: _destination,
                      readOnly: true,
                      placeholder: '选择保存位置…',
                      onTap: _running || _complete || _picking
                          ? null
                          : _pickDestination,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: '选择目标目录与文件名',
                    child: IconButton(
                      icon: const Icon(FluentIcons.folder_open, size: 18),
                      onPressed: _running || _complete || _picking
                          ? null
                          : _pickDestination,
                    ),
                  ),
                ],
              ),
              if (_running) ...[
                const SizedBox(height: 16),
                ProgressBar(value: percent),
                const SizedBox(height: 8),
                Text(
                  _cancelling
                      ? '正在取消并清理临时文件…'
                      : _seconds == 0
                      ? '正在准备超分与编码器…'
                      : '正在导出$percentLabel'
                            ' · 已处理 ${_seconds.toStringAsFixed(1)} 秒',
                ),
              ],
              if (_complete) ...[
                const SizedBox(height: 16),
                const InfoBar(
                  title: Text('导出完成'),
                  severity: InfoBarSeverity.success,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                InfoBar(
                  title: const Text('导出失败'),
                  content: Text(_error!),
                  severity: InfoBarSeverity.error,
                ),
              ],
            ],
          ),
        ),
        actions: [
          Button(
            onPressed: _cancelling
                ? null
                : () {
                    if (_running) {
                      setState(() => _cancelling = true);
                      _export.cancel();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
            child: Text(_complete ? '关闭' : '取消'),
          ),
          if (!_complete)
            FilledButton(
              onPressed:
                  _running ||
                      _picking ||
                      unavailable != null ||
                      _destination.text.isEmpty
                  ? null
                  : _start,
              child: const Text('开始导出'),
            ),
        ],
      ),
    );
  }
}
