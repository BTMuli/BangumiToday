// Package imports:
import 'package:flutter_riverpod/legacy.dart';

// Project imports:
import '../../models/bangumi/bangumi_enum.dart';

/// 监听收藏状态变更
class SubjectCollectStatProvider extends StateNotifier<bool> {
  /// 构造函数
  SubjectCollectStatProvider() : super(false);

  BangumiCollectionType type = BangumiCollectionType.unknown;

  int epStatus = 0;

  bool get collected => state;

  /// set
  void set(bool value, {BangumiCollectionType? type, int? epStatus}) {
    if (type != null) this.type = type;
    if (epStatus != null) this.epStatus = epStatus;
    if (!value) {
      this.type = BangumiCollectionType.unknown;
      this.epStatus = 0;
    }
    state = value;
  }
}

/// 监听Rss变更
class SubjectRssStatProvider extends StateNotifier<String?> {
  /// 构造函数
  SubjectRssStatProvider() : super(null);

  /// set
  void set(String value) => state = value;
}
