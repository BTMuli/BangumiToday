// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/bt_engine/protocol.dart';

Map<String, dynamic> _taskJson() => {
  'id': 't1',
  'state': 'downloading',
  'sourceKind': 'torrent',
  'manual': false,
  'savePath': r'C:\Downloads',
  'downloadMilliseconds': 1000,
  'totalBytes': 100,
  'downloadedBytes': 40,
};

Map<String, dynamic> _detailsJson() => {
  'task': _taskJson(),
  'pieceLength': 16,
  'pieceCount': 10,
  'completedPieces': 'AAAA',
  'files': [
    {
      'path': 'a.mkv',
      'size': 100,
      'completedBytes': 40,
      'priority': 4,
      'isPadding': false,
    },
  ],
  'filesTruncated': false,
  'totalFiles': 1,
  'contentFiles': 1,
  'peers': <Map<String, dynamic>>[],
  'peersTruncated': false,
  'totalPeers': 0,
  'trackerUrls': <String>[],
  'httpConnections': 0,
  'httpRangeSupported': null,
  'httpTransferMode': 'none',
  'httpResponseStatus': null,
};

void main() {
  test('BtTaskDetails.fromJson 解析任务与文件计数', () {
    var details = BtTaskDetails.fromJson(_detailsJson());
    expect(details.task.id, 't1');
    expect(details.pieceLength, 16);
    expect(details.contentFileCount, 1);
    expect(details.files, hasLength(1));
    expect(details.files.single.path, 'a.mkv');
    expect(details.httpTransferMode, 'none');
    expect(details.httpRangeSupported, isNull);
  });

  test('BtTaskDetails.fromJson 缺少 contentFiles 时失败', () {
    var json = _detailsJson()..remove('contentFiles');
    expect(() => BtTaskDetails.fromJson(json), throwsA(isA<TypeError>()));
  });

  test('BtTaskDetails.fromJson 缺少 httpTransferMode 时失败', () {
    var json = _detailsJson()..remove('httpTransferMode');
    expect(() => BtTaskDetails.fromJson(json), throwsA(isA<TypeError>()));
  });
}
