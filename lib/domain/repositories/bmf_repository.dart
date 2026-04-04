import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/bmf_rss_service.dart';
import '../../database/app/app_bmf.dart';
import '../../database/app/app_rss.dart';
import '../../models/database/app_bmf_model.dart';
import '../../store/bmf_store.dart';

final bmfRepositoryProvider = Provider<BmfRepository>((ref) {
  return BmfRepository(ref);
});

class BmfRepository {
  final Ref _ref;
  final BtsAppBmf _sqlite = BtsAppBmf();
  final BtsAppRss _rssDb = BtsAppRss();

  BmfRepository(this._ref);

  Future<List<AppBmfModel>> readAll() async {
    return _sqlite.readAll();
  }

  Future<AppBmfModel?> read(int subject) async {
    return _sqlite.read(subject);
  }

  Future<void> write(AppBmfModel model) async {
    await _sqlite.write(model);
    _ref.read(bmfStoreProvider).onBmfAdded(model);
  }

  Future<void> update(AppBmfModel model) async {
    await _sqlite.write(model);
    _ref.read(bmfStoreProvider).onBmfUpdated(model);
  }

  Future<void> delete(int subject) async {
    var existing = await _sqlite.read(subject);
    if (existing != null) {
      if (existing.rss != null && existing.rss!.isNotEmpty) {
        await _rssDb.delete(existing.rss!);
      }
    }
    await _sqlite.delete(subject);
    _ref.read(bmfStoreProvider).onBmfDeleted(subject);
  }

  Future<bool> checkRss(String rss, {int? excludeSubject}) async {
    return _sqlite.checkRss(rss, excludeSubject: excludeSubject);
  }

  Future<bool> checkDir(String dir, {int? excludeSubject}) async {
    return _sqlite.checkDir(dir, excludeSubject: excludeSubject);
  }

  Future<void> refreshRss(AppBmfModel model) async {
    await BmfRssService.instance.onBmfWritten(model);
  }
}
