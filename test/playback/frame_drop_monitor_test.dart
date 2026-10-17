// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/models/playback/playback_frame_drop_monitor.dart';

void main() {
  test('正常推理抽帧不触发降级，连续掉帧保留判定窗口', () {
    var monitor = PlaybackFrameDropMonitor();
    for (var i = 0; i <= 5; i++) {
      expect(
        monitor.observe(
          dropped: 0,
          frame: 48 * i,
          position: 2 * i,
          elapsed: Duration(seconds: 2 * i),
          expectedFramesPerSecond: 24,
        ),
        isFalse,
      );
    }
    for (var i = 6; i <= 8; i++) {
      expect(
        monitor.observe(
          dropped: i - 5,
          frame: 48 * i,
          position: 2 * i,
          elapsed: Duration(seconds: 2 * i),
          expectedFramesPerSecond: 24,
        ),
        i == 8,
      );
    }
    expect(monitor.lastWindow, {
      'wall_seconds': 2.0,
      'inferred_frames': 48,
      'vo_drops': 1,
      'inferred_fps': 24.0,
      'expected_fps': 24.0,
      'drop_fraction': 1 / 48,
      'drop_threshold': 0.01,
      'minimum_fps': 5.0,
      'starved': false,
      'consecutive_bad_windows': 3,
      'required_bad_windows': 3,
    });
    monitor.reset();
    expect(monitor.lastWindow, isNull);
  });

  test('零输出仍触发保护，暂停样本间隙清空旧判定', () {
    var monitor = PlaybackFrameDropMonitor();
    for (var i = 0; i <= 3; i++) {
      expect(
        monitor.observe(
          dropped: 0,
          frame: 0,
          position: 2 * i,
          elapsed: Duration(seconds: 2 * i),
          expectedFramesPerSecond: 24,
        ),
        i == 3,
      );
    }
    expect(monitor.lastWindow!['starved'], isTrue);
    expect(
      monitor.observe(
        dropped: 0,
        frame: 0,
        position: 16,
        elapsed: const Duration(seconds: 16),
        expectedFramesPerSecond: 24,
      ),
      isFalse,
    );
    expect(monitor.lastWindow, isNull);
  });
}
