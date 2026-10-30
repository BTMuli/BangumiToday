// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/bt_engine/protocol.dart';

BtTaskPeerDetail _peer(String userAgent) => BtTaskPeerDetail(
  endpoint: '127.0.0.1:6881',
  userAgent: userAgent,
  peerId: '-qB4670-iAmK57upA!M)'.codeUnits
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join(),
  peerIdClient: 'Transmission 9.9',
  progress: .5,
  downloadRate: 0,
  uploadRate: 0,
  choked: false,
  interested: true,
  remoteChoked: false,
  remoteInterested: false,
  connectionState: 'connected',
  seed: false,
  transport: 'tcp',
  encryption: 'none',
  sources: const [],
  trackerUrls: const [],
);

void main() {
  test('名称和版本来自实际 UA，保持完整声明供复制', () {
    var peer = _peer('qBittorrent/4.6.7');
    expect(peer.clientName, 'qBittorrent');
    expect(peer.clientVersion, '4.6.7');
    expect(peer.userAgent, 'qBittorrent/4.6.7');
    expect(peer.peerIdClient, 'Transmission 9.9');
  });

  test('支持空格分隔及带预发布版本的 UA', () {
    var cases = {
      'libtorrent 2.0.12': ('libtorrent', '2.0.12'),
      'qBittorrent/5.0.0-beta1': ('qBittorrent', '5.0.0-beta1'),
      'Client/1.2.3+build7': ('Client', '1.2.3+build7'),
    };
    for (var entry in cases.entries) {
      var peer = _peer(entry.key);
      expect(
        (peer.clientName, peer.clientVersion),
        entry.value,
        reason: entry.key,
      );
      expect(peer.userAgent, entry.key);
    }
  });

  test('缺少 UA 时不会以 Peer ID 指纹补齐', () {
    var peer = _peer('');
    expect(peer.userAgent, isEmpty);
    expect(peer.clientName, 'unknown');
    expect(peer.clientVersion, isEmpty);
  });

  test('复合或未知声明完整保留，不把附带库版本当作客户端版本', () {
    for (var value in ['Custom Client', 'Client/1.0 libtorrent/2.0']) {
      var peer = _peer(value);
      expect(peer.clientName, value);
      expect(peer.clientVersion, isEmpty);
      expect(peer.userAgent, value);
    }
  });

  test('Peer ID 保留完整可读标识并独立于 UA', () {
    var first = _peer('qBittorrent/4.6.7');
    var second = _peer('Another Client/1.0');
    expect(first.peerIdLabel, '-qB4670-iAmK57upA!M)');
    expect(second.peerIdLabel, first.peerIdLabel);
  });
}
