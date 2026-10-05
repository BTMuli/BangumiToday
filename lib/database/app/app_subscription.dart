// Project imports:
import '../bt_sqlite.dart';
import '../drift/subscription_storage.dart';

/// Application singleton connection; state transitions live in the pure store.
SubscriptionStorage get appSubscriptionStorage =>
    SubscriptionStorage(BTSqlite().db);
