// Dart imports:
import 'dart:isolate';

// Project imports:
import '../../models/bangumi/bangumi_data_model.dart';

/// Model construction also belongs off the UI isolate after Dio decodes JSON.
Future<BangumiDataJson> parseBangumiDataset(Map<String, dynamic> data) =>
    Isolate.run(() => BangumiDataJson.fromJson(data));
