// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/bt_engine/protocol.dart';
import 'package:bangumi_today/pages/download/download_task_helpers.dart';

Map<String, dynamic> _task({
  required String id,
  required int downloadRate,
  String state = 'downloading',
  int downloadedBytes = 0,
  int totalBytes = 1000,
}) => {
  'id': id,
  'state': state,
  'sourceKind': 'http',
  'manual': true,
  'savePath': r'C:\Downloads',
  'downloadMilliseconds': 1000,
  'downloadRate': downloadRate,
  'uploadRate': 0,
  'downloadedBytes': downloadedBytes,
  'totalBytes': totalBytes,
  'progress': totalBytes == 0 ? 0.0 : downloadedBytes / totalBytes,
};

void main() {
  test('成员签名忽略速率变化', () {
    var a = BtTaskSnapshot.fromJson(_task(id: 'a', downloadRate: 100));
    var b = BtTaskSnapshot.fromJson(_task(id: 'a', downloadRate: 900));
    expect(DownloadTaskMembership([a]), DownloadTaskMembership([b]));
    var paused = BtTaskSnapshot.fromJson(
      _task(id: 'a', downloadRate: 0, state: 'paused'),
    );
    expect(
      DownloadTaskMembership([a]),
      isNot(DownloadTaskMembership([paused])),
    );
  });

  test('速率排序在采样快照上稳定，采样更新后才换序', () {
    var slowFirst = [
      BtTaskSnapshot.fromJson(_task(id: 'a', downloadRate: 100)),
      BtTaskSnapshot.fromJson(_task(id: 'b', downloadRate: 50)),
    ];
    var flipped = [
      BtTaskSnapshot.fromJson(_task(id: 'a', downloadRate: 10)),
      BtTaskSnapshot.fromJson(_task(id: 'b', downloadRate: 500)),
    ];
    var first = DownloadTaskOrder(
      DownloadTaskSortValues(
        slowFirst,
        DownloadTaskSortField.downloadRate,
      ).sortedIds(descending: true),
    );
    var sticky = first;
    var live = DownloadTaskOrder(
      DownloadTaskSortValues(
        flipped,
        DownloadTaskSortField.downloadRate,
      ).sortedIds(descending: true),
    );
    // 采样期内继续使用上一份顺序，列表不会因瞬时速率抖动换位。
    expect(sticky.ids, ['a', 'b']);
    expect(live.ids, ['b', 'a']);
    expect(sticky, isNot(live));
  });
}
