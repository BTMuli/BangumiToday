// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/bt_engine/protocol.dart';

Map<String, dynamic> _task(String id, int elapsed) => {
  'id': id,
  'state': 'paused',
  'sourceKind': 'http',
  'manual': true,
  'savePath': r'C:\Downloads',
  'downloadMilliseconds': elapsed,
};

void main() {
  test('耗时属于单个任务，零速度快照保留累计值', () {
    var a = BtTaskSnapshot.fromJson(_task('a', 123456));
    var b = BtTaskSnapshot.fromJson(_task('b', 7000));
    expect(a.downloadMilliseconds, 123456);
    expect(a.downloadRate, 0);
    expect(b.downloadMilliseconds, 7000);
  });

  test('耗时变化参与快照相等性以刷新显示', () {
    var original = BtTaskSnapshot.fromJson(_task('a', 1000));
    var repeated = BtTaskSnapshot.fromJson(_task('a', 1000));
    var advanced = BtTaskSnapshot.fromJson(_task('a', 1500));
    expect(original, repeated);
    expect(original.hashCode, repeated.hashCode);
    expect(original, isNot(advanced));
  });

  test('拒绝负耗时及缺失协议字段', () {
    expect(
      () => BtTaskSnapshot.fromJson(_task('a', -1)),
      throwsFormatException,
    );
    var missing = _task('a', 0)..remove('downloadMilliseconds');
    expect(() => BtTaskSnapshot.fromJson(missing), throwsA(isA<TypeError>()));
  });
}
