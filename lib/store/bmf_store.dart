import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app/app_bmf.dart';
import '../models/database/app_bmf_model.dart';

enum BmfChangeType { add, update, delete }

class BmfChangeEvent {
  final BmfChangeType type;
  final AppBmfModel? item;
  final int? subjectId;

  BmfChangeEvent({required this.type, this.item, this.subjectId});
}

final bmfListProvider =
    AsyncNotifierProvider<BmfListNotifier, List<AppBmfModel>>(() {
      return BmfListNotifier();
    });

class BmfListNotifier extends AsyncNotifier<List<AppBmfModel>> {
  final BtsAppBmf _sqlite = BtsAppBmf();

  @override
  Future<List<AppBmfModel>> build() async {
    var list = await _sqlite.readAll();
    list.sort((a, b) => b.subject.compareTo(a.subject));
    return list;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      var list = await _sqlite.readAll();
      list.sort((a, b) => b.subject.compareTo(a.subject));
      return list;
    });
  }

  void addItem(AppBmfModel item) {
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
    var current = state.value ?? [];
    var index = current.indexWhere((e) => e.subject == item.subject);
    if (index != -1) {
      var updated = List<AppBmfModel>.from(current);
      updated[index] = item;
      state = AsyncValue.data(updated);
    }
  }

  void removeItem(int subjectId) {
    var current = state.value ?? [];
    state = AsyncValue.data(
      current.where((e) => e.subject != subjectId).toList(),
    );
  }

  AppBmfModel? getBySubject(int subject) {
    var current = state.value;
    if (current == null) return null;
    try {
      return current.firstWhere((e) => e.subject == subject);
    } catch (_) {
      return null;
    }
  }
}
