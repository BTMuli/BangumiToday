/// Source resolution comes from the selected codec and its decoder, never
/// from the output device or a lossy decoder's floating-point container.
class PlaybackAudioSource {
  const PlaybackAudioSource({
    required this.id,
    required this.codec,
    required this.sampleRate,
    required this.format,
    required this.channels,
    this.encodedBits,
  });

  final String id;
  final String codec;
  final int sampleRate;
  final String format;
  final int channels;
  final int? encodedBits;

  bool get lossless =>
      codec.startsWith('pcm_') ||
      const {'flac', 'alac', 'truehd', 'mlp', 'ape', 'tta'}.contains(codec);

  bool get lossy => const {
    'aac',
    'aac_latm',
    'ac3',
    'eac3',
    'mp1',
    'mp2',
    'mp3',
    'opus',
    'vorbis',
    'wmav1',
    'wmav2',
    'wmapro',
  }.contains(codec);

  int? get pcmBits => int.tryParse(
    RegExp(r'^pcm_[suf](\d+)').firstMatch(codec)?.group(1) ?? '',
  );
  int? get bits =>
      encodedBits ??
      pcmBits ??
      (const {'ape', 'tta'}.contains(codec) &&
              const {'s32', 's32p'}.contains(format)
          ? 24
          : null);

  /// These decoders select s16 for <= 16 bits and s32 for > 16 bits.
  /// s32 does not establish the exact encoded depth (e.g. FLAC 24 vs 32).
  int get minimumBits =>
      bits ??
      switch (format) {
        's16' || 's16p' => 16,
        // FFmpeg's TrueHD parser always assigns 24, even for a 16-bit
        // recording. Its s32 output alone cannot prove a HiRes source.
        's32' || 's32p' when codec == 'truehd' => 0,
        's32' || 's32p'
            when const {'flac', 'alac', 'mlp', 'ape', 'tta'}.contains(codec) =>
          17,
        _ => 0,
      };

  bool get hiRes =>
      lossless && sampleRate > 0 && (sampleRate > 48000 || minimumBits > 16);

  // For unknown encoded depth, preserve the full decoder precision.
  int get requiredPrecision => bits == null
      ? codec == 'truehd'
            ? 24
            : playbackAudioPrecision(format)
      : codec.startsWith('pcm_f')
      ? playbackAudioPrecision(format)
      : bits!;

  String get precisionLabel => lossy
      ? '有损编码（$format 解码）'
      : bits != null
      ? '$bits 位${codec.startsWith('pcm_f') ? '浮点' : ''}'
      : minimumBits > 16
      ? '>16 位（$format 解码）'
      : minimumBits == 16
      ? '16 位'
      : '源位深未知（$format 解码）';

  String get description =>
      '$codec · ${playbackAudioRate(sampleRate)} · '
      '$precisionLabel · $channels 声道';
}

class PlaybackAudioOutput {
  const PlaybackAudioOutput({
    required this.sampleRate,
    required this.format,
    required this.channels,
    required this.driver,
    this.devicePrecision,
    this.exclusive,
  });

  final int sampleRate;
  final String format;
  final int channels;
  final String driver;
  final int? devicePrecision;
  final bool? exclusive;

  int get precision =>
      devicePrecision ??
      (driver == 'wasapi' ? 0 : playbackAudioPrecision(format));

  String get description =>
      '${playbackAudioRate(sampleRate)} · $format'
      '${devicePrecision == null ? '' : '（有效 $devicePrecision 位）'} · '
      '$channels 声道 · $driver'
      '${exclusive == null ? '' : ' · ${exclusive! ? '独占' : '共享'}'}';
}

/// mpv's pinned WASAPI backend reports the accepted WAVEFORMAT here. Its
/// s32 audio-out-params can represent 24 valid bits in a 32-bit container.
class PlaybackWasapiFormat {
  const PlaybackWasapiFormat(
    this.format,
    this.precision,
    this.sampleRate,
    this.exclusive,
  );
  final String format;
  final int precision;
  final int sampleRate;
  final bool exclusive;

  static PlaybackWasapiFormat? parse(String text) {
    var match = RegExp(
      r'^Accepted as .* -> .* (\S+) '
      r'\((\d+)/(\d+) bits\) @ (\d+)hz \((exclusive|shared)\)',
    ).firstMatch(text.trim());
    if (match == null) return null;
    var format = match[1]!;
    var valid = int.parse(match[3]!);
    return PlaybackWasapiFormat(
      format,
      format == 'float' ? 24 : valid,
      int.parse(match[4]!),
      match[5] == 'exclusive',
    );
  }
}

/// Floating-point storage size is not its effective sample precision.
int playbackAudioPrecision(String format) => switch (format) {
  'u8' || 'u8p' => 8,
  's16' || 's16p' => 16,
  's32' || 's32p' => 32,
  's64' || 's64p' => 64,
  'float' || 'floatp' || 'flt' || 'fltp' => 24,
  'double' || 'doublep' || 'dbl' || 'dblp' => 53,
  _ => 0,
};

String playbackAudioRate(int rate) => rate <= 0
    ? '采样率未知'
    : '${rate / 1000 == rate ~/ 1000 ? rate ~/ 1000 : rate / 1000} kHz';

class PlaybackHiResState {
  const PlaybackHiResState({
    this.source,
    this.output,
    this.requested = false,
    this.configured = false,
    this.exclusiveRequested = false,
    this.supported = true,
    this.rate = 1,
    this.failure,
  });

  final PlaybackAudioSource? source;
  final PlaybackAudioOutput? output;
  final bool requested;
  final bool configured;
  final bool exclusiveRequested;
  final bool supported;
  final double rate;
  final String? failure;

  bool get available => supported && (source?.hiRes ?? false);

  /// Device failures must still recover while playing at a different rate.
  String? get deviceMismatch {
    var input = source;
    var actual = output;
    if (input == null || actual == null || actual.sampleRate <= 0) {
      return '等待输出设备参数';
    }
    if (!const {'wasapi', 'coreaudio'}.contains(actual.driver)) {
      return '当前输出设备不支持此 HiRes 模式';
    }
    if (actual.driver == 'wasapi' && actual.exclusive != exclusiveRequested) {
      var mode = exclusiveRequested ? '独占' : '共享';
      return actual.exclusive == null ? '等待设备$mode格式确认' : '设备未进入$mode输出';
    }
    // A shared device uses the system mix format. Conversion is reported as
    // a fidelity limitation, not a device failure requiring audio recovery.
    return exclusiveRequested ? _formatMismatch : null;
  }

  String? get _formatMismatch {
    var input = source;
    var actual = output;
    if (input == null || actual == null) return null;
    if (actual.sampleRate != input.sampleRate) return '设备未保持源采样率';
    if (input.requiredPrecision == 0 ||
        actual.precision < input.requiredPrecision) {
      return '设备输出精度不足或无法确认';
    }
    if (actual.channels != input.channels) return '设备未保持源声道数';
    return null;
  }

  String? get outputMismatch =>
      deviceMismatch ?? _formatMismatch ?? (rate == 1 ? null : '倍速播放中');

  bool get active =>
      requested &&
      configured &&
      available &&
      failure == null &&
      outputMismatch == null;

  String get status {
    if (!supported) return '当前平台不支持 HiRes 输出';
    if (source == null) return '等待当前音轨参数';
    if (!source!.lossless) return '当前音轨未确认为 HiRes 无损音源';
    if (!source!.hiRes) {
      return source!.minimumBits == 0 ? '源精度无法确认' : '当前音源为普通解析度';
    }
    if (!requested) return 'HiRes 音源 · 点击启用 HiRes';
    if (failure != null) return 'HiRes 输出失败：$failure';
    var mode = exclusiveRequested ? '独占输出' : '共享输出';
    if (!configured) return '正在切换 HiRes $mode';
    var mismatch = outputMismatch;
    return mismatch == null
        ? 'HiRes 已启用 · $mode · 保持源采样率和精度'
        : 'HiRes $mode · $mismatch';
  }

  String get tooltip =>
      '音源：${source?.description ?? '等待检测'}\n'
      '输出：${output?.description ?? '等待设备参数'}\n$status'
      '${requested ? '\n点击关闭 HiRes' : ''}';
}
