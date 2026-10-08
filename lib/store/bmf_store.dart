// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../core/utils/async_pool.dart';
import '../domain/repositories/bmf_repository.dart';
import '../models/database/app_bmf_model.dart';
import '../providers/bangumi_providers.dart';
import '../providers/bmf_providers.dart';
import '../tools/log_tool.dart';

final bmfListProvider =
    AsyncNotifierProvider<BmfListNotifier, List<AppBmfModel>>(() {
      return BmfListNotifier();
    });

final bmfNavigationProvider =
    NotifierProvider<BmfNavigationNotifier, BmfNavigationState>(
      BmfNavigationNotifier.new,
    );

/// BMF 工作区的导航意图：打开工作区、待处理列表或定位到某个条目。
///
/// 每次意图都递增 [requestId]，消费者据此判断是否为新请求，因此该状态必须
/// 可比较且不可变；[targetSubject] 为空时由 [pendingUpdatesOnly] 决定视图。
class BmfNavigationState {
  /// 构造函数
  const BmfNavigationState({
    this.targetSubject,
    this.pendingUpdatesOnly = false,
    this.requestId = 0,
  });

  /// 需要定位的条目。
  final int? targetSubject;

  /// 是否打开待处理更新列表。
  final bool pendingUpdatesOnly;

  /// 意图序号，递增即代表产生了新请求。
  final int requestId;

  /// 产生下一个导航意图。
  BmfNavigationState next({
    int? targetSubject,
    bool pendingUpdatesOnly = false,
  }) {
    return BmfNavigationState(
      targetSubject: targetSubject,
      pendingUpdatesOnly: pendingUpdatesOnly,
      requestId: requestId + 1,
    );
  }
}

class BmfNavigationNotifier extends Notifier<BmfNavigationState> {
  @override
  BmfNavigationState build() => const BmfNavigationState();

  /// 回到工作区默认视图。
  void openWorkspace() => state = state.next();

  /// 打开待处理更新列表。
  void openPendingUpdates() => state = state.next(pendingUpdatesOnly: true);

  /// 定位到指定条目。
  void selectSubject(int subject) {
    state = state.next(targetSubject: subject);
  }
}

class BmfListNotifier extends AsyncNotifier<List<AppBmfModel>> {
  static const int _airDateLookupConcurrency = 4;

  final Map<int, AppBmfModel> _bmfMap = {};
  StreamSubscription<BmfChange>? _changes;

  Map<int, AppBmfModel> get bmfMap => Map.unmodifiable(_bmfMap);

  @override
  Future<List<AppBmfModel>> build() async {
    var repository = ref.watch(bmfRepositoryProvider);
    // 由状态层订阅仓储变更，而不是让数据层反向持有 notifier。
    _changes = repository.changes.listen(_onChange);
    ref.onDispose(() {
      unawaited(_changes?.cancel());
      _changes = null;
    });
    var list = await _readAllWithAirDates(repository);
    _syncMap(list);
    list.sort((a, b) => b.subject.compareTo(a.subject));
    return list;
  }

  void _onChange(BmfChange change) {
    var model = change.model;
    if (model == null) {
      if (change.kind == BmfChangeKind.removed) removeItem(change.subject);
      return;
    }
    if (change.kind == BmfChangeKind.added) {
      addItem(model);
    } else {
      updateItem(model);
    }
  }

  Future<List<AppBmfModel>> _readAllWithAirDates(
    BmfRepository repository,
  ) async {
    var list = await repository.readAll();
    var missing = list
        .where((item) => item.airDate == null || item.airDate!.isEmpty)
        .toList();
    if (missing.isEmpty) return list;

    await forEachConcurrent(
      missing,
      maxConcurrent: _airDateLookupConcurrency,
      action: (item) async {
        try {
          var response = await ref
              .read(bangumiRepositoryProvider)
              .getSubjectDetail(item.subject.toString());
          if (response.code != 0 || response.data == null) return;
          var airDate = response.data!.date;
          if (airDate == null || airDate.isEmpty) return;
          item.airDate = airDate;
          await repository.updateAirDate(item.subject, airDate);
        } catch (error, stackTrace) {
          BTLogTool.warn([
            '补全 BMF 放送日期失败: subject=${item.subject}',
            error.toString(),
            stackTrace.toString(),
          ]);
        }
      },
    );
    return list;
  }

  void _syncMap(List<AppBmfModel> list) {
    _bmfMap.clear();
    for (var item in list) {
      _bmfMap[item.subject] = item;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      var list = await _readAllWithAirDates(ref.read(bmfRepositoryProvider));
      _syncMap(list);
      list.sort((a, b) => b.subject.compareTo(a.subject));
      return list;
    });
  }

  void addItem(AppBmfModel item) {
    _bmfMap[item.subject] = item;
    var current = state.value;
    if (current == null) return;
    var index = current.indexWhere((e) => e.subject == item.subject);
    if (index == -1) {
      state = AsyncValue.data([item, ...current]);
    } else {
      var updated = List<AppBmfModel>.from(current);
      updated[index] = item;
      state = AsyncValue.data(updated);
    }
  }

  void updateItem(AppBmfModel item) {
    _bmfMap[item.subject] = item;
    var current = state.value;
    if (current == null) return;
    var index = current.indexWhere((e) => e.subject == item.subject);
    if (index != -1) {
      var updated = List<AppBmfModel>.from(current);
      updated[index] = item;
      state = AsyncValue.data(updated);
    }
  }

  void removeItem(int subjectId) {
    _bmfMap.remove(subjectId);
    var current = state.value;
    if (current == null) return;
    var updated = current.where((e) => e.subject != subjectId).toList();
    state = AsyncValue.data(updated);
  }

  AppBmfModel? getBySubject(int subject) {
    return _bmfMap[subject];
  }
}
