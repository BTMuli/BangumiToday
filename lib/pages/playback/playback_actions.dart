import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../database/app/app_bmf.dart';
import '../../models/playback/playback_item.dart';
import '../../store/nav_store.dart';
import '../../store/playback_store.dart';
import '../../ui/bt_infobar.dart';

Future<void> openLocalPlayback(
  BuildContext context,
  WidgetRef ref,
  String filePath, {
  int? subject,
}) async {
  try {
    var store = ref.read(playbackStoreProvider);
    if (subject == null) {
      var key = PlaybackItem.pathKey(filePath);
      var associations = await BtsAppBmf().readAll();
      associations.sort(
        (a, b) => (b.download?.length ?? 0).compareTo(a.download?.length ?? 0),
      );
      for (var association in associations) {
        var root = association.download;
        if (root != null &&
            root.isNotEmpty &&
            path.isWithin(PlaybackItem.pathKey(root), key)) {
          subject = association.subject;
          break;
        }
      }
    }
    await store.library.ensureReady(filePath);
    var items = await store.library.discover(
      path.dirname(filePath),
      subject: subject,
    );
    await store.open(items, filePath);
    ref.read(navStoreProvider).goToPlayback();
  } catch (error) {
    if (context.mounted) await BtInfobar.error(context, error.toString());
  }
}

Future<void> resumeLocalPlayback(
  BuildContext context,
  WidgetRef ref,
  PlaybackItem item,
) async {
  await openLocalPlayback(context, ref, item.filePath, subject: item.subject);
}
