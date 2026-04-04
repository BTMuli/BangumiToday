import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app/app_bmf.dart';
import '../models/database/app_bmf_model.dart';

final bmfListProvider =
    AsyncNotifierProvider<BmfListNotifier, List<AppBmfModel>>(() {
      return BmfListNotifier();
    });

class BmfListNotifier extends AsyncNotifier<List<AppBmfModel>> {
  final BtsAppBmf _sqlite = BtsAppBmf();
  final Map<int, AppBmfModel> _bmfMap = {};

  Map<int, AppBmfModel> get bmfMap => Map.unmodifiable(_bmfMap);

  @override
  Future<List<AppBmfModel>> build() async {
    var list = await _sqlite.readAll();
    _syncMap(list);
    list.sort((a, b) => b.subject.compareTo(a.subject));
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
      var list = await _sqlite.readAll();
      _syncMap(list);
      list.sort((a, b) => b.subject.compareTo(a.subject));
      return list;
    });
  }

  void addItem(AppBmfModel item) {
    _bmfMap[item.subject] = item;
    var current = state.value ?? [];
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
    var current = state.value ?? [];
    var index = current.indexWhere((e) => e.subject == item.subject);
    if (index != -1) {
      var updated = List<AppBmfModel>.from(current);
      updated[index] = item;
      state = AsyncValue.data(updated);
    }
  }

  void removeItem(int subjectId) {
    _bmfMap.remove(subjectId);
    var current = state.value ?? [];
    state = AsyncValue.data(
      current.where((e) => e.subject != subjectId).toList(),
    );
  }

  AppBmfModel? getBySubject(int subject) {
    return _bmfMap[subject];
  }
}
