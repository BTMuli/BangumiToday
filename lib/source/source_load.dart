// Project imports:
import 'core/source_base.dart';
import 'modules/bimi/bimi_source.dart';
import 'modules/giri/giri_source.dart';

final bangumiSource = <BtSourceBase>[
  GiriSource(),
  BimiSource(),
];

/// 根据源名称获取源
BtSourceBase getSourceByName(String name) {
  // 如果以 GiriGiriLove 开头
  if (name.startsWith('GiriGiriLove')) {
    return bangumiSource[0];
  }
  // 如果以 哔咪动漫 开头
  if (name.startsWith('哔咪动漫')) {
    return bangumiSource[1];
  }
  return bangumiSource[0];
}
