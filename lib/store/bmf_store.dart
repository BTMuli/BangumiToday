import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../database/app/app_bmf.dart';
import '../models/database/app_bmf_model.dart';

enum BmfChangeType { add, update, delete }

class BmfChangeEvent {
  final BmfChangeType type;
  final AppBmfModel? item;
  final int? subjectId;

  BmfChangeEvent({required this.type, this.item, this.subjectId});
}

final bmfStoreProvider = ChangeNotifierProvider<BmfStore>((ref) {
  return BmfStore();
});

class BmfStore extends ChangeNotifier {
  List<AppBmfModel> _bmfList = [];
  bool _isLoading = false;
  String? _error;
  int _version = 0;

  List<AppBmfModel> get bmfList => _bmfList;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get version => _version;

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var sqlite = BtsAppBmf();
      _bmfList = await sqlite.readAll();
      _bmfList.sort((a, b) => b.subject.compareTo(a.subject));
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void onBmfAdded(AppBmfModel item) {
    var index = _bmfList.indexWhere((e) => e.subject == item.subject);
    if (index == -1) {
      _bmfList.insert(0, item);
    } else {
      _bmfList[index] = item;
    }
    _version++;
    notifyListeners();
  }

  void onBmfUpdated(AppBmfModel item) {
    var index = _bmfList.indexWhere((e) => e.subject == item.subject);
    if (index != -1) {
      _bmfList[index] = item;
      _version++;
      notifyListeners();
    }
  }

  void onBmfDeleted(int subjectId) {
    _bmfList.removeWhere((e) => e.subject == subjectId);
    _version++;
    notifyListeners();
  }

  void notifyBmfChanged() {
    _version++;
    notifyListeners();
  }

  AppBmfModel? getBySubject(int subject) {
    try {
      return _bmfList.firstWhere((e) => e.subject == subject);
    } catch (_) {
      return null;
    }
  }
}
