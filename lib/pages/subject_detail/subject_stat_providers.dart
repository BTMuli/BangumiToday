// Flutter imports:
import 'package:flutter/foundation.dart';

// Project imports:
import '../../models/bangumi/bangumi_enum.dart';

/// 条目收藏状态：是否已收藏、收藏类型与看到第几话。
///
/// 这是详情页自己的会话状态，每个页面实例一份，不参与跨页共享，
/// 因此保持普通可监听对象，不引入 Riverpod provider。
@immutable
class SubjectCollectStat {
  /// 构造函数
  const SubjectCollectStat({
    this.collected = false,
    this.type = BangumiCollectionType.unknown,
    this.epStatus = 0,
  });

  /// 是否已收藏
  final bool collected;

  /// 收藏类型
  final BangumiCollectionType type;

  /// 已看话数
  final int epStatus;

  /// 拷贝
  SubjectCollectStat copyWith({
    bool? collected,
    BangumiCollectionType? type,
    int? epStatus,
  }) {
    return SubjectCollectStat(
      collected: collected ?? this.collected,
      type: type ?? this.type,
      epStatus: epStatus ?? this.epStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SubjectCollectStat) return false;
    return collected == other.collected &&
        type == other.type &&
        epStatus == other.epStatus;
  }

  @override
  int get hashCode => Object.hash(collected, type, epStatus);
}

/// 监听收藏状态变更
class SubjectCollectStatProvider extends ChangeNotifier {
  SubjectCollectStat _state = const SubjectCollectStat();

  /// 当前收藏状态
  SubjectCollectStat get state => _state;

  /// 是否已收藏
  bool get collected => _state.collected;

  /// 收藏类型
  BangumiCollectionType get type => _state.type;

  /// 已看话数
  int get epStatus => _state.epStatus;

  /// set
  void set(bool value, {BangumiCollectionType? type, int? epStatus}) {
    var next = _state.copyWith(
      collected: value,
      type: value ? type : BangumiCollectionType.unknown,
      epStatus: value ? epStatus : 0,
    );
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  /// 注册监听并返回取消监听的闭包。
  ///
  /// 沿用此前 StateNotifier 的用法，便于组件在 dispose 时保存移除函数。
  VoidCallback listen(VoidCallback listener) {
    addListener(listener);
    return () => removeListener(listener);
  }
}

/// 监听Rss变更
class SubjectRssStatProvider extends ChangeNotifier {
  String? _state;

  /// 当前 RSS 地址
  String? get state => _state;

  /// set
  void set(String value) {
    if (_state == value) return;
    _state = value;
    notifyListeners();
  }

  /// 注册监听并返回取消监听的闭包。
  VoidCallback listen(VoidCallback listener) {
    addListener(listener);
    return () => removeListener(listener);
  }
}
