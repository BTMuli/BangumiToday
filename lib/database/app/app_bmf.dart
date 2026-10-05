// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import '../../models/database/app_bmf_model.dart';
import '../../models/database/app_subscription_model.dart';
import '../bt_sqlite.dart';
import '../drift/bt_database.dart';
import '../drift/subscription_storage.dart';

class BtsAppBmf {
  BtsAppBmf._();
  static final BtsAppBmf instance = BtsAppBmf._();
  factory BtsAppBmf() => instance;
  BtDatabase get _db => BTSqlite().db;

  Future<List<AppBmfModel>> readAll() async {
    var rows = await (_db.select(
      _db.appBmf,
    )..orderBy([(b) => OrderingTerm.desc(b.subject)])).get();
    var subscriptions = await SubscriptionStorage(_db).readAll();
    var byBmf = <int, List<AppSubscriptionModel>>{};
    for (var subscription in subscriptions) {
      byBmf.putIfAbsent(subscription.bmfId, () => []).add(subscription);
    }
    return rows
        .map(
          (r) => AppBmfModel.fromJson({
            ...r.toJson(),
            'subscriptions':
                byBmf[r.id]?.map((s) => s.toJson()).toList() ??
                <Map<String, dynamic>>[],
          }),
        )
        .toList();
  }

  Future<AppBmfModel?> read(int subject) async {
    var row = await _findBySubject(subject);
    if (row == null) return null;
    var subscriptions = await SubscriptionStorage(_db).readAll(bmfId: row.id);
    return AppBmfModel.fromJson({
      ...row.toJson(),
      'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
    });
  }

  Future<void> write(AppBmfModel model) async {
    await _db.transaction(() async {
      var existing = await _findBySubject(model.subject);
      var values = AppBmfCompanion(
        subject: Value(model.subject),
        title: Value(model.title),
        airDate: Value(model.airDate),
        download: Value(model.download),
      );
      int id;
      if (existing == null) {
        id = await _db.into(_db.appBmf).insert(values);
      } else {
        id = existing.id;
        await (_db.update(
          _db.appBmf,
        )..where((b) => b.id.equals(id))).write(values);
      }
      await SubscriptionStorage(_db).saveSubscriptions(id, model.subscriptions);
    });
  }

  Future<void> updateAirDate(int subject, String airDate) async {
    await (_db.update(_db.appBmf)..where((b) => b.subject.equals(subject)))
        .write(AppBmfCompanion(airDate: Value(airDate)));
  }

  Future<void> delete(int subject) =>
      SubscriptionStorage(_db).deleteBmf(subject);

  /// Feeds may be shared by different BMFs; duplicates within a BMF are checked
  /// transactionally when saving the complete subscription collection.
  Future<bool> checkRss(String input, {int? excludeSubject}) async => false;

  Future<bool> checkDir(String dir, {int? excludeSubject}) async {
    var query = _db.select(_db.appBmf)..where((b) => b.download.equals(dir));
    if (excludeSubject != null) {
      query.where((b) => b.subject.equals(excludeSubject).not());
    }
    return (await query.get()).isNotEmpty;
  }

  Future<BmfRow?> _findBySubject(int subject) => (_db.select(
    _db.appBmf,
  )..where((b) => b.subject.equals(subject))).getSingleOrNull();
}
