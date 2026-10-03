// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
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
    await store.openLocalFile(filePath, subject: subject);
    ref.read(navStoreProvider.notifier).goToPlayback();
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
