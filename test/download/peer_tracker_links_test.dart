// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/bt_engine/protocol.dart';

Map<String, dynamic> _peer(List<int> trackerIndices) => {
  'endpoint': '127.0.0.1:6881',
  'userAgent': 'qBittorrent/4.6.7',
  'peerId': '',
  'peerIdClient': '',
  'progress': .5,
  'downloadRate': 1,
  'uploadRate': 0,
  'choked': false,
  'interested': true,
  'remoteChoked': false,
  'remoteInterested': true,
  'connectionState': 'connected',
  'seed': false,
  'transport': 'tcp',
  'encryption': 'none',
  'sources': ['tracker', 'dht'],
  'trackerIndices': trackerIndices,
};

Map<String, dynamic> _page(List<int> trackerIndices) => {
  'peers': [_peer(trackerIndices)],
  'trackerUrls': ['https://a/announce', 'udp://b:80/announce'],
  'peersTruncated': true,
  'totalPeers': 101,
  'offset': 0,
  'nextOffset': 100,
};

void main() {
  test('按字典索引还原同一个 Peer 的多个具体 Tracker', () {
    var page = BtTaskPeersResult.fromJson(_page([1, 0]));
    expect(page.peers.single.trackerUrls, [
      'udp://b:80/announce',
      'https://a/announce',
    ]);
    expect(page.totalPeers, 101);
    expect(page.nextOffset, 100);
  });

  test('泛化的 Tracker 来源标志不推断具体 Tracker', () {
    var page = BtTaskPeersResult.fromJson(_page([]));
    expect(page.peers.single.sources, contains('tracker'));
    expect(page.peers.single.trackerUrls, isEmpty);
  });

  test('未知字典索引立即暴露协议错误', () {
    expect(() => BtTaskPeersResult.fromJson(_page([2])), throwsRangeError);
  });

  test('关联字段缺失时不回退旧协议', () {
    var page = _page([])..remove('trackerUrls');
    expect(() => BtTaskPeersResult.fromJson(page), throwsA(isA<TypeError>()));
    var peer = _peer([])..remove('trackerIndices');
    expect(
      () => BtTaskPeerDetail.fromJson(peer, trackerUrls: const []),
      throwsA(isA<TypeError>()),
    );
  });
}
