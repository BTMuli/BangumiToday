part of 'playback_page.dart';

/// A read-only OSD with scrolling when its content exceeds the video height.
class _PlaybackVideoInfo extends StatefulWidget {
  const _PlaybackVideoInfo({
    super.key,
    required this.player,
    required this.item,
    required this.store,
  });

  final Player player;
  final PlaybackItem item;
  final PlaybackStore store;

  @override
  State<_PlaybackVideoInfo> createState() => _PlaybackVideoInfoState();
}

class _PlaybackVideoInfoState extends State<_PlaybackVideoInfo> {
  Timer? _timer;
  bool _reading = false;
  Map<String, String> _properties = {};

  static const _propertyNames = [
    'file-format',
    'file-size',
    'hwdec-current',
    'estimated-vf-fps',
    'video-bitrate',
    'frame-drop-count',
    'decoder-frame-drop-count',
    'estimated-frame-number',
    'estimated-frame-count',
    'avsync',
    'current-vo',
    'current-ao',
    'audio-out-params/format',
    'audio-out-params/samplerate',
    'audio-out-params/channel-count',
    'display-fps',
    'mpv-version',
    'current-tracks/video/id',
    'current-tracks/video/codec',
    'current-tracks/video/decoder-desc',
    'current-tracks/video/demux-fps',
    'current-tracks/audio/id',
    'current-tracks/audio/codec',
    'current-tracks/audio/decoder-desc',
    'current-tracks/sub/id',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_read()));
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_read()),
    );
  }

  Future<void> _read() async {
    if (!mounted || _reading || !TickerMode.valuesOf(context).enabled) {
      return;
    }
    // The windowed surface stays mounted beneath the fullscreen route.
    if (ModalRoute.of(context)?.isCurrent == false) return;
    var native = widget.player.platform;
    if (native is! NativePlayer || native.disposed) return;
    _reading = true;
    try {
      var entries = await Future.wait(
        _propertyNames.map((name) async {
          try {
            var value = await native
                // The mounted surface already owns an initialized player.
                // Avoid leaving pending initialization waits during shutdown.
                .getProperty(name, waitForInitialization: false)
                .timeout(const Duration(milliseconds: 500));
            return MapEntry(name, value);
          } catch (_) {
            // Missing stream data is displayed as —.
            return MapEntry(name, '');
          }
        }),
      );
      if (mounted) setState(() => _properties = Map.fromEntries(entries));
    } finally {
      _reading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _property(String name) => _value(_properties[name]);

  static String _value(Object? value) =>
      value == null || value.toString().isEmpty ? '—' : value.toString();

  static String _bitrate(num? value) => value == null
      ? '—'
      : value >= 1000000
      ? '${(value / 1000000).toStringAsFixed(2)} Mbps'
      : '${(value / 1000).toStringAsFixed(1)} kbps';

  static String _size(String? value) {
    var bytes = double.tryParse(value ?? '');
    if (bytes == null) return '—';
    return bytes >= 1073741824
        ? '${(bytes / 1073741824).toStringAsFixed(2)} GiB'
        : '${(bytes / 1048576).toStringAsFixed(1)} MiB';
  }

  static String _resolution(int? width, int? height) =>
      width == null || height == null ? '—' : '$width × $height';

  Widget _line(String label, String value, Color color, {int? maxLines}) =>
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label：',
              style: const TextStyle(color: Colors.white),
            ),
            TextSpan(
              text: value,
              style: TextStyle(color: color),
            ),
          ],
        ),
        maxLines: maxLines,
        overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
      );

  @override
  Widget build(BuildContext context) {
    var state = widget.player.state;
    var video = state.videoParams;
    var audio = state.audioParams;
    // The public track setting can remain "auto". Resolve the actual mpv
    // selection instead of assuming that the first available track is playing.
    var videoTrack = state.tracks.video.firstWhere(
      (track) => track.id == _properties['current-tracks/video/id'],
      orElse: () => state.track.video,
    );
    var audioTrack = state.tracks.audio.firstWhere(
      (track) => track.id == _properties['current-tracks/audio/id'],
      orElse: () => state.track.audio,
    );
    var subtitle = state.tracks.subtitle.firstWhere(
      (track) => track.id == _properties['current-tracks/sub/id'],
      orElse: () => state.track.subtitle,
    );
    var percentage = state.duration > Duration.zero
        ? (state.position.inMilliseconds / state.duration.inMilliseconds * 100)
              .clamp(0.0, 100.0)
              .toStringAsFixed(1)
        : '—';
    var videoBitrate =
        double.tryParse(_properties['video-bitrate'] ?? '') ??
        videoTrack.bitrate;
    var fps =
        (double.tryParse(_properties['current-tracks/video/demux-fps'] ?? '') ??
                videoTrack.fps)
            ?.toStringAsFixed(3) ??
        '—';
    var videoCodec = _properties['current-tracks/video/codec'];
    if (videoCodec == null || videoCodec.isEmpty) videoCodec = videoTrack.codec;
    var audioCodec = _properties['current-tracks/audio/codec'];
    if (audioCodec == null || audioCodec.isEmpty) audioCodec = audioTrack.codec;
    var outputFps =
        double.tryParse(
          _properties['estimated-vf-fps'] ?? '',
        )?.toStringAsFixed(3) ??
        '—';
    var sync = double.tryParse(_properties['avsync'] ?? '');
    var hwdec = _property('hwdec-current');
    if (hwdec == 'no') hwdec = '软件解码';
    var sourceSize = _resolution(
      videoTrack.w ?? video.w ?? state.width,
      videoTrack.h ?? video.h ?? state.height,
    );
    var hardwarePixelFormat = video.hwPixelformat;
    var hardwarePixelText = hardwarePixelFormat == null
        ? ''
        : ' / $hardwarePixelFormat';
    var syncText = sync == null
        ? '—'
        : '${(sync * 1000).toStringAsFixed(1)} ms';
    var audioBitrate = _bitrate(state.audioBitrate ?? audioTrack.bitrate);
    var positionText = _playbackTime(state.position, milliseconds: true);
    var durationText = _playbackTime(state.duration, milliseconds: true);
    var outputSize = _resolution(video.dw ?? video.w, video.dh ?? video.h);
    var upscale = widget.store.upscaler;
    var requested = upscale?.plan.output;
    var texture = upscale?.actualOutput;
    var audioFormatText = _value(audio.format);
    var audioSampleRateText = _value(audio.sampleRate);
    var audioChannelCountText = _value(audio.channelCount);
    var audioChannelsText = _value(audio.channels);
    var now = DateTime.now();
    var clock = [
      now.hour,
      now.minute,
      now.second,
    ].map((value) => value.toString().padLeft(2, '0')).join(':');
    const yellow = Color(0xFFFFE27A);
    const cyan = Color(0xFF67E8F9);
    const pink = Color(0xFFFF8BCD);
    const green = Color(0xFF8FE6A1);
    const blue = Color(0xFF8FB6FF);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Grow to the longest line, using all available space before wrapping.
        // IntrinsicWidth keeps shorter content from stretching across the video.
        return Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth,
              maxHeight: constraints.maxHeight,
            ),
            child: IntrinsicWidth(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontFamilyFallback: const ['Cascadia Mono', 'monospace'],
                      fontSize: constraints.maxWidth >= 1000 ? 16 : 13,
                      height: 1.5,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                          offset: Offset(1, 1),
                        ),
                        Shadow(
                          color: Colors.black,
                          blurRadius: 2,
                          offset: Offset(-1, -1),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _line('文件名', widget.item.title, yellow, maxLines: 2),
                        _line(
                          '时间轴',
                          '$positionText / $durationText '
                              '($percentage%)   当前时间：$clock',
                          cyan,
                        ),
                        _line(
                          '状态',
                          '${state.buffering
                                  ? '正在缓冲'
                                  : state.playing
                                  ? '播放中'
                                  : '已暂停'}'
                              '   速度：${PlaybackRateMemory.label(state.rate)}×'
                              '   音量：${state.volume.round()}%'
                              '   文件：${_property('file-format')} / '
                              '${_size(_properties['file-size'])}',
                          green,
                        ),
                        const SizedBox(height: 10),
                        _line(
                          '视频解码器',
                          '${_property('current-tracks/video/decoder-desc')}'
                              '   硬件解码：$hwdec',
                          pink,
                        ),
                        _line(
                          '视频输入',
                          '${_value(videoCodec)}   '
                              '$sourceSize   '
                              '帧率：$fps fps   位率：${_bitrate(videoBitrate)}',
                          yellow,
                        ),
                        _line(
                          '像素与色彩',
                          '${_value(video.pixelformat)}'
                              '$hardwarePixelText'
                              '   ${_value(video.colormatrix)}'
                              ' / ${_value(video.primaries)}'
                              ' / ${_value(video.gamma)}'
                              ' / ${_value(video.colorlevels)}',
                          blue,
                        ),
                        _line(
                          '视频显示参数',
                          '$outputSize   渲染帧率：$outputFps fps'
                              '   渲染器：${_property('current-vo')}',
                          pink,
                        ),
                        if (upscale != null) ...[
                          _line(
                            '视频超分',
                            '${widget.store.upscaleMode.label} · '
                                '${upscale.plan.reason}',
                            cyan,
                          ),
                          _line(
                            '纹理输出',
                            '请求：${_resolution(requested?.width, requested?.height)}'
                                '   实际：${_resolution(texture?.width, texture?.height)}',
                            pink,
                          ),
                          _line(
                            'GPU',
                            '${_value(upscale.renderer)}'
                                '   纹理上限：—   pass 耗时：—',
                            blue,
                          ),
                        ],
                        _line(
                          '帧统计',
                          '估算帧：${_property('estimated-frame-number')} / '
                              '${_property('estimated-frame-count')}'
                              '   渲染丢帧：${_property('frame-drop-count')}'
                              '   解码丢帧：${_property('decoder-frame-drop-count')}'
                              '   A/V：$syncText',
                          green,
                        ),
                        const SizedBox(height: 10),
                        _line(
                          '音频解码器',
                          '${_property('current-tracks/audio/decoder-desc')}'
                              ' / ${_value(audioCodec)}',
                          pink,
                        ),
                        _line(
                          '音频输入',
                          '$audioFormatText   $audioSampleRateText Hz '
                              '$audioChannelCountText 声道 '
                              '($audioChannelsText)   位率：$audioBitrate',
                          yellow,
                        ),
                        _line(
                          '音频输出',
                          '${_property('audio-out-params/format')}   '
                              '${_property('audio-out-params/samplerate')} Hz   '
                              '${_property('audio-out-params/channel-count')} 声道'
                              '   渲染器：${_property('current-ao')}',
                          pink,
                        ),
                        _line(
                          '字幕',
                          _playbackTrackLabel(
                            subtitle.id,
                            subtitle.title,
                            subtitle.language,
                          ),
                          blue,
                        ),
                        const SizedBox(height: 10),
                        _line(
                          '播放器',
                          '${_property('mpv-version')}   '
                              '显示刷新率：${_property('display-fps')} Hz',
                          cyan,
                        ),
                        const Text(
                          'Tab 或右键菜单关闭 · — 表示当前媒体未提供数据',
                          style: TextStyle(
                            color: material.Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
