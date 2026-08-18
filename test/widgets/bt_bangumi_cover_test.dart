// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/constants/app_constants.dart';
import 'package:bangumi_today/request/bangumi/bangumi_api.dart';
import 'package:bangumi_today/widgets/bangumi/bt_bangumi_cover.dart';

void main() {
  tearDown(() {
    BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiApiBaseUrl);
  });

  test('grid covers request 0x400 and strip an existing r/ prefix', () {
    expect(
      BangumiCoverUrl.resolve('https://lain.bgm.tv/r/0x600/pic/cover/l/a.jpg'),
      '${BtrBangumiApi.imageBaseUrl}/r/0x400/pic/cover/l/a.jpg',
    );
  });

  test('detail covers can keep the 600px request edge', () {
    expect(
      BangumiCoverUrl.resolve(
        'https://lain.bgm.tv/pic/cover/l/a.jpg',
        maxEdge: BangumiCoverUrl.detailMaxEdge,
      ),
      '${BtrBangumiApi.imageBaseUrl}/r/0x600/pic/cover/l/a.jpg',
    );
  });

  test('memCache keeps the larger layout edge in device pixels', () {
    var size = BangumiCoverUrl.memCacheSize(
      logicalWidth: 80,
      logicalHeight: 120,
      devicePixelRatio: 2,
    );
    expect(size.width, isNull);
    expect(size.height, 240);
    expect(size.height, lessThan(600));
  });
}
