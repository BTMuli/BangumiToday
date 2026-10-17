// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/playback_tensorrt_resources.dart';
import 'package:bangumi_today/models/playback/playback_janai_status.dart';

PlaybackJanaiStatus _status({
  String phase = 'active',
  int frames = 1,
  double milliseconds = 25,
  String reason = '',
  int driver = 13040,
  List<String> lines = const [],
}) => PlaybackJanaiStatus(
  phase: phase,
  backend: 'tensorrt',
  reason: reason,
  backendReason: '',
  frames: frames,
  gpuMilliseconds: milliseconds,
  gpuName: 'NVIDIA GeForce RTX 4070 Laptop GPU',
  gpuVendor: 0x10de,
  gpuSm: 89,
  gpuDriver: driver,
  buildLines: lines,
);

void main() {
  test('更新动态计数保留最新值，连续 500 次采样不重复通知页面', () {
    var notifications = 0;
    var resources = PlaybackTensorRtResources(onChanged: () => notifications++);
    addTearDown(resources.dispose);
    resources.observe(_status());
    expect(notifications, 1);
    for (var i = 2; i <= 501; i++) {
      resources.observe(_status(frames: i, milliseconds: i / 10));
    }
    expect(notifications, 1);
    expect(resources.native!.frames, 501);
    expect(resources.native!.gpuMilliseconds, 50.1);
  });

  test('首次输出、显卡变化、错误和清空状态仍通知页面', () {
    var notifications = 0;
    var resources = PlaybackTensorRtResources(onChanged: () => notifications++);
    addTearDown(resources.dispose);
    resources.observe(_status(frames: 0));
    resources.observe(_status());
    resources.observe(_status(driver: 13050));
    resources.observe(_status(phase: 'failed', reason: 'GPU failure'));
    resources.observe(null);
    expect(notifications, 5);
    resources.observe(null);
    expect(notifications, 5);
  });

  test('编译输出按内容比较，同样的行不会反复通知，进展仍可见', () {
    var notifications = 0;
    var resources = PlaybackTensorRtResources(onChanged: () => notifications++);
    addTearDown(resources.dispose);
    resources.observe(_status(phase: 'preparing', lines: ['first']));
    resources.observe(_status(phase: 'preparing', lines: ['first']));
    resources.observe(_status(phase: 'preparing', lines: ['second']));
    expect(notifications, 2);
    expect(resources.lines, ['second']);
  });
}
