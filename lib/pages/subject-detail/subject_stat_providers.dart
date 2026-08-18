// Package imports:
import 'package:flutter_riverpod/legacy.dart';

/// 监听收藏状态变更
class SubjectCollectStatProvider extends StateNotifier<bool> {
  /// 构造函数
  SubjectCollectStatProvider() : super(false);

  /// set
  void set(bool value) => state = value;
}

/// 监听Rss变更
class SubjectRssStatProvider extends StateNotifier<String?> {
  /// 构造函数
  SubjectRssStatProvider() : super(null);

  /// set
  void set(String value) => state = value;
}
