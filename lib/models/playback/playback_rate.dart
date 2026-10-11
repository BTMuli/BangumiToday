/// Remembers the latest non-normal rate for Z across app sessions.
class PlaybackRateMemory {
  PlaybackRateMemory({required this.read, required this.write});

  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  Future<void>? _loadFuture;
  double? _remembered;

  double? get remembered => _remembered;

  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    var rate = double.tryParse(await read() ?? '');
    if (rate != null &&
        rate.isFinite &&
        rate >= 0.1 &&
        rate <= 3 &&
        rate != 1) {
      _remembered = rate;
    }
  }

  /// Called serially by the playback store, together with applying the rate.
  Future<void> remember(double current) async {
    var rate = normalize(current);
    await load();
    if (rate == 1 || rate == _remembered) return;
    await write(rate.toString());
    _remembered = rate;
  }

  /// Switching to normal speed must not overwrite the remembered rate.
  Future<double> toggle(double current) async {
    await load();
    if ((current - 1).abs() < 0.000001) return _remembered ?? 1;
    await remember(current);
    return 1;
  }

  static double normalize(double rate) {
    if (!rate.isFinite) throw ArgumentError.value(rate, 'rate');
    return (rate.clamp(0.1, 3.0) * 100).round() / 100;
  }

  static double step(double current, double delta) =>
      normalize(current + delta);

  static String label(double rate) =>
      rate.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}
