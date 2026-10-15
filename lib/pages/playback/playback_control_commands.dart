part of 'playback_page.dart';

/// Shared command handling for shortcuts, buttons and menus.
extension _PlaybackControlCommands on _PlaybackVideoControlsState {
  void _execute(_PlaybackCommand command) {
    unawaited(widget.run(() => _perform(command)));
  }

  Future<void> _perform(_PlaybackCommand command) async {
    var store = widget.store;
    var player = widget.player;
    var overlay = widget.overlay;
    if (!mounted || store.player != player || store.current == null) return;
    _showChrome();
    if (command == _PlaybackCommand.info) {
      overlay.toggleInfo();
      return;
    }
    if (command == _PlaybackCommand.help) {
      overlay.toggleHelp();
      _scheduleHide();
      if (!overlay.showHelp) _focusVideo();
      return;
    }
    if (command == _PlaybackCommand.escape) {
      if (overlay.showHelp) {
        overlay.toggleHelp();
        _focusVideo();
        _scheduleHide();
      } else if (isFullscreen(context)) {
        overlay.closeMenus();
        await exitFullscreen(context);
        overlay.show('退出全屏', material.Icons.fullscreen_exit_rounded);
      }
      return;
    }
    if (command == _PlaybackCommand.scaleHalf ||
        command == _PlaybackCommand.scaleOriginal ||
        command == _PlaybackCommand.scaleOneHalf) {
      await _applyWindowScale(command);
      return;
    }
    if (command == _PlaybackCommand.fullscreen) {
      var fullscreen = isFullscreen(context);
      overlay.closeMenus();
      await toggleFullscreen(context);
      overlay.show(
        fullscreen ? '退出全屏' : '进入全屏',
        fullscreen
            ? material.Icons.fullscreen_exit_rounded
            : material.Icons.fullscreen_rounded,
      );
      return;
    }
    if (store.loading || store.isOpening) {
      overlay.show(
        store.openingStatus ?? '正在加载视频…',
        material.Icons.hourglass_top_rounded,
      );
      return;
    }
    switch (command) {
      case _PlaybackCommand.toggle:
      case _PlaybackCommand.play:
      case _PlaybackCommand.pause:
        var pause =
            command == _PlaybackCommand.pause ||
            (command == _PlaybackCommand.toggle && player.state.playing);
        await (pause ? store.pause() : player.play());
        overlay.show(
          pause ? '已暂停' : '继续播放',
          pause
              ? material.Icons.pause_rounded
              : material.Icons.play_arrow_rounded,
        );
      case _PlaybackCommand.back5:
      case _PlaybackCommand.forward5:
      case _PlaybackCommand.back10:
      case _PlaybackCommand.forward10:
        var seconds = switch (command) {
          _PlaybackCommand.back5 => -5,
          _PlaybackCommand.forward5 => 5,
          _PlaybackCommand.back10 => -10,
          _ => 10,
        };
        var duration = player.state.duration;
        var target = player.state.position + Duration(seconds: seconds);
        if (target < Duration.zero) target = Duration.zero;
        if (duration > Duration.zero && target > duration) target = duration;
        await player.seek(target);
        overlay.show(
          '${seconds < 0 ? '后退' : '前进'} ${seconds.abs()} 秒',
          seconds < 0
              ? material.Icons.fast_rewind_rounded
              : material.Icons.fast_forward_rounded,
          detail: '${_playbackTime(target)} / ${_playbackTime(duration)}',
          level: duration > Duration.zero
              ? target.inMilliseconds / duration.inMilliseconds
              : null,
        );
      case _PlaybackCommand.previousChapter:
      case _PlaybackCommand.nextChapter:
        var chapters = _availableChapters;
        var next = command == _PlaybackCommand.nextChapter;
        var chapter = adjacentPlaybackChapter(
          chapters,
          player.state.position,
          next: next,
        );
        if (chapter == null) {
          overlay.show(
            chapters.isEmpty
                ? '此视频没有章节信息'
                : next
                ? '已经是最后一个章节'
                : '已经是第一个章节',
            material.Icons.bookmark_outline_rounded,
          );
          return;
        }
        await _seekChapter(chapter);
      case _PlaybackCommand.volumeUp:
      case _PlaybackCommand.volumeDown:
      case _PlaybackCommand.mute:
        var volume = player.state.volume;
        if (command == _PlaybackCommand.mute) {
          if (volume > 0) {
            overlay.audibleVolume = volume;
            volume = 0;
          } else {
            volume = overlay.audibleVolume;
          }
        } else {
          volume = (volume + (command == _PlaybackCommand.volumeUp ? 5 : -5))
              .clamp(0.0, 100.0);
        }
        await player.setVolume(volume);
        if (volume > 0) overlay.audibleVolume = volume;
        overlay.show(
          volume == 0 ? '已静音' : '音量 ${volume.round()}%',
          volume == 0
              ? material.Icons.volume_off_rounded
              : material.Icons.volume_up_rounded,
          level: volume / 100,
        );
      case _PlaybackCommand.slower:
      case _PlaybackCommand.faster:
        await store.stepRate(command == _PlaybackCommand.faster ? 0.1 : -0.1);
        overlay.show(
          '播放速度 ${PlaybackRateMemory.label(player.state.rate)}×',
          material.Icons.speed_rounded,
        );
      case _PlaybackCommand.toggleRate:
        await store.toggleRate();
        overlay.show(
          '播放速度 ${PlaybackRateMemory.label(player.state.rate)}×',
          material.Icons.speed_rounded,
          detail: store.rememberedRate == null
              ? '先调整倍速，之后可按 Z 切换 1× / 记忆倍速'
              : 'Z 可切换 1× / ${PlaybackRateMemory.label(store.rememberedRate!)}×',
        );
      case _PlaybackCommand.previous:
      case _PlaybackCommand.next:
        var nextIndex =
            store.index + (command == _PlaybackCommand.next ? 1 : -1);
        if (nextIndex < 0 || nextIndex >= store.playlist.length) {
          overlay.show(
            nextIndex < 0 ? '已经是第一个视频' : '已经是最后一个视频',
            material.Icons.playlist_play_rounded,
          );
          return;
        }
        await store.jump(nextIndex);
        if (store.player != player || store.current == null) return;
        overlay.show(
          command == _PlaybackCommand.next ? '下一个视频' : '上一个视频',
          command == _PlaybackCommand.next
              ? material.Icons.skip_next_rounded
              : material.Icons.skip_previous_rounded,
          detail: PlaybackLabel.fromName(
            store.current!.title,
            filePath: store.current!.filePath,
          ).title,
        );
      case _PlaybackCommand.fullscreen:
      case _PlaybackCommand.escape:
      case _PlaybackCommand.info:
      case _PlaybackCommand.help:
      case _PlaybackCommand.scaleHalf:
      case _PlaybackCommand.scaleOriginal:
      case _PlaybackCommand.scaleOneHalf:
        return;
      case _PlaybackCommand.screenshot:
        await _copyScreenshot();
    }
  }

  List<PlaybackChapter> get _availableChapters {
    var duration = widget.player.state.duration;
    return [
      for (var chapter in widget.store.chapters)
        if (duration <= Duration.zero || chapter.start < duration) chapter,
    ];
  }

  Future<void> _seekChapter(PlaybackChapter chapter) async {
    if (widget.store.loading || !mounted) return;
    await widget.player.seek(chapter.start);
    widget.overlay.show(
      chapter.title,
      material.Icons.bookmark_outline_rounded,
      detail: _playbackTime(chapter.start),
    );
  }

  Future<void> _copyScreenshot() async {
    if (_takingScreenshot) return;
    _takingScreenshot = true;
    var overlay = widget.overlay;
    try {
      var screenshot = await widget.store.captureScreenshot();
      if (screenshot == null) return;
      var systemClipboard = clipboard.SystemClipboard.instance;
      if (systemClipboard == null) {
        throw const PlaybackUnavailable('当前平台不支持复制图片到剪贴板');
      }
      // The captured bytes remain valid after a playlist or controls change.
      var item = clipboard.DataWriterItem()
        ..add(clipboard.Formats.png(screenshot.image));
      await systemClipboard.write([item]);
      overlay.show(
        '截图已复制到剪贴板',
        material.Icons.photo_camera_outlined,
        detail: _playbackTime(screenshot.position),
      );
    } finally {
      _takingScreenshot = false;
    }
  }

  /// 数字键调整无边框窗口尺寸：1/2/3 对应视频像素的 0.5 / 1 / 1.5 倍。
  /// 2 倍在 1080p 上会超出工作区并被钳制，实测表现异常，因此不提供。
  Future<void> _applyWindowScale(_PlaybackCommand command) async {
    var mode = widget.windowMode;
    var overlay = widget.overlay;
    if (mode == null) {
      overlay.show(
        '当前窗口不支持调整尺寸',
        material.Icons.aspect_ratio_rounded,
        detail: '独立播放器窗口可按 1 / 2 / 3 调整',
      );
      return;
    }
    var (scale, label) = switch (command) {
      _PlaybackCommand.scaleHalf => (0.5, '0.5 倍'),
      _PlaybackCommand.scaleOneHalf => (1.5, '1.5 倍'),
      _ => (1.0, '原始像素'),
    };
    var fullscreen = isFullscreen(context);
    if (fullscreen) {
      overlay.closeMenus();
      // 原生退出回调与尺寸调整使用同一窗口操作队列，先恢复窗口再缩放。
      await exitFullscreen(context);
    }
    var base = mode.scaleBaseSize;
    var applied = await mode.setVideoScale(scale, center: fullscreen);
    if (applied == null) {
      overlay.show('暂时无法调整窗口尺寸', material.Icons.aspect_ratio_rounded);
      return;
    }
    var detail = mode.videoSize == null
        ? '未播放视频，按 ${base.width.round()} × ${base.height.round()} 基准'
        : '视频原始 ${base.width.round()} × ${base.height.round()}';
    if (applied.clamped) {
      detail =
          '屏幕可用区域不足，已限制为 '
          '${applied.size.width.round()} × ${applied.size.height.round()}';
    }
    overlay.show(
      '窗口尺寸 · $label',
      material.Icons.aspect_ratio_rounded,
      detail: detail,
    );
  }
}
