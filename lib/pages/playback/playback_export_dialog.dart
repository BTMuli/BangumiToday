// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart' as material;

// Package imports:
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../core/services/playback_tensorrt_resources.dart';
import '../../core/services/playback_video_export.dart';
import '../../models/playback/playback_export.dart';
import '../../models/playback/playback_upscale.dart';
import '../../widgets/common/bt_icon_toggle_group.dart';

class PlaybackExportDialog extends StatefulWidget {
  const PlaybackExportDialog({
    super.key,
    required this.source,
    required this.video,
    required this.fps,
    required this.duration,
    required this.initialMode,
    required this.initialResolution,
    required this.resources,
  });

  final String source;
  final PlaybackVideoSource video;
  final double fps;
  final Duration duration;
  final PlaybackUpscaleMode initialMode;
  final PlaybackExportResolution initialResolution;
  final PlaybackTensorRtResources resources;

  @override
  State<PlaybackExportDialog> createState() => _PlaybackExportDialogState();
}

class _PlaybackExportDialogState extends State<PlaybackExportDialog> {
  static const _modeIcons = {
    PlaybackUpscaleMode.light: material.Icons.bolt_rounded,
    PlaybackUpscaleMode.standard: material.Icons.tune_rounded,
    PlaybackUpscaleMode.high: material.Icons.high_quality_rounded,
    PlaybackUpscaleMode.janaiSmooth: material.Icons.speed_rounded,
    PlaybackUpscaleMode.janaiQuality: material.Icons.auto_awesome_rounded,
  };

  final _export = PlaybackVideoExport();
  final _destination = TextEditingController();
  late PlaybackUpscaleMode _mode;
  late PlaybackExportResolution _resolution;
  FluentDialogRoute<bool>? _cancelConfirmation;
  bool _customDestination = false;
  bool _running = false;
  bool _cancelling = false;
  bool _complete = false;
  bool _picking = false;
  double _seconds = 0;
  String? _error;

  PlaybackExportFormat? get _sourceFormat =>
      PlaybackExportFormat.fromExtension(path.extension(widget.source));
  PlaybackExportFormat get _format =>
      PlaybackExportFormat.fromExtension(path.extension(_destination.text)) ??
      PlaybackExportFormat.mkv;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode == PlaybackUpscaleMode.off
        ? PlaybackUpscaleMode.standard
        : widget.initialMode;
    _resolution = widget.initialResolution;
    _updateDefaultDestination();
  }

  @override
  void dispose() {
    _export.cancel();
    _destination.dispose();
    super.dispose();
  }

  void _updateDefaultDestination() {
    if (_customDestination) return;
    var extension = _sourceFormat == null
        ? '.mkv'
        : path.extension(widget.source);
    _destination.text = path.join(
      path.dirname(widget.source),
      '${path.basenameWithoutExtension(widget.source)}'
      '_${_mode.name}_${_resolution.label}$extension',
    );
  }

  void _updateOptions({
    PlaybackUpscaleMode? mode,
    PlaybackExportResolution? resolution,
  }) {
    setState(() {
      _mode = mode ?? _mode;
      _resolution = resolution ?? _resolution;
      _updateDefaultDestination();
      _error = null;
    });
  }

  Future<void> _pickDestination() async {
    setState(() => _picking = true);
    try {
      var result = await getSaveLocation(
        initialDirectory: path.dirname(_destination.text),
        suggestedName: path.basename(_destination.text),
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
        _customDestination = true;
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

  Future<void> _requestCancel() async {
    var navigator = Navigator.of(context);
    if (!_running) {
      navigator.pop();
      return;
    }
    if (_cancelling || _cancelConfirmation != null) return;
    var confirmation = FluentDialogRoute<bool>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierDismissible: true,
      builder: (context) => ContentDialog(
        title: const Text('取消导出？'),
        content: const Text('取消后，已处理的进度将丢失。'),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续导出'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
    _cancelConfirmation = confirmation;
    try {
      var confirmed = await navigator.push(confirmation);
      if (!mounted || !_running || confirmed != true) return;
      setState(() => _cancelling = true);
      _export.cancel();
    } finally {
      _cancelConfirmation = null;
    }
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _error = null;
      _seconds = 0;
    });
    var cancelled = false;
    try {
      var completed = await _export.run(
        source: widget.source,
        destination: _destination.text,
        allowOverwrite: _customDestination,
        video: widget.video,
        mode: _mode,
        resolution: _resolution,
        fps: widget.fps,
        resources: widget.resources,
        onProgress: (seconds) {
          if (mounted) setState(() => _seconds = seconds);
        },
      );
      if (!mounted) return;
      cancelled = !completed;
      if (completed) setState(() => _complete = true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) {
        var confirmation = _cancelConfirmation;
        if (confirmation != null && confirmation.isActive) {
          Navigator.of(context).removeRoute(confirmation);
        }
        setState(() {
          _running = false;
          _cancelling = false;
        });
      }
    }
    if (mounted && cancelled) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    PlaybackPixels? size;
    String? unavailable;
    if (_mode.isJanai && !widget.resources.canEnable) {
      unavailable = '请先在应用设置中安装 TensorRT 组件';
    } else {
      try {
        size = playbackExportSize(widget.video, _mode, _resolution);
      } on StateError catch (error) {
        unavailable = error.message;
      }
    }
    var editing = !_running && !_complete && !_picking;
    var total = widget.duration.inMilliseconds / 1000;
    var percent = total > 0 ? (_seconds / total * 100).clamp(0.0, 99.9) : null;
    var percentLabel = percent == null
        ? ''
        : ' · ${percent.toStringAsFixed(1)}%';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestCancel());
      },
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
              Row(
                children: [
                  const Expanded(child: Text('超分档位')),
                  BTIconToggleGroup<PlaybackUpscaleMode>(
                    value: _mode,
                    options: [
                      for (var MapEntry(key: mode, value: icon)
                          in _modeIcons.entries)
                        BTIconToggleOption(
                          value: mode,
                          label:
                              '${mode.isJanai ? 'JaNai' : 'Anime4K'}'
                              ' · ${mode.label}',
                          icon: icon,
                        ),
                    ],
                    onChanged: editing
                        ? (mode) => _updateOptions(mode: mode)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('导出分辨率')),
                  BTIconToggleGroup<PlaybackExportResolution>(
                    value: _resolution,
                    options: [
                      for (var resolution in PlaybackExportResolution.values)
                        BTIconToggleOption(
                          value: resolution,
                          label:
                              '${resolution.label} · '
                              '${resolution.width} × ${resolution.height}',
                          icon: switch (resolution) {
                            PlaybackExportResolution.qhd =>
                              material.Icons.two_k_rounded,
                            PlaybackExportResolution.uhd =>
                              material.Icons.four_k_rounded,
                          },
                        ),
                    ],
                    onChanged: editing
                        ? (resolution) => _updateOptions(resolution: resolution)
                        : null,
                  ),
                ],
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
              if (_sourceFormat == null && !_customDestination)
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
                      onTap: editing ? _pickDestination : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: '选择目标目录与文件名',
                    child: IconButton(
                      icon: const Icon(FluentIcons.folder_open, size: 18),
                      onPressed: editing ? _pickDestination : null,
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
            onPressed: _cancelling ? null : _requestCancel,
            child: Text(_complete ? '关闭' : '取消'),
          ),
          if (!_complete)
            FilledButton(
              onPressed: editing && unavailable == null ? _start : null,
              child: const Text('开始导出'),
            ),
        ],
      ),
    );
  }
}
