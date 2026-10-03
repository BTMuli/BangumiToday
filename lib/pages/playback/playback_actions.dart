import 'dart:io';

// Package imports:
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/services/playback_window_service.dart';
import '../../models/playback/playback_item.dart';
import '../../providers/playback_window_providers.dart';
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
    var child = ref.read(isPlaybackWindowProvider);
    if (Platform.isWindows && !child) {
      await ref
          .read(playbackWindowServiceProvider)
          .open(filePath: filePath, subject: subject);
      return;
    }
    var store = ref.read(playbackStoreProvider);
    await store.openLocalFile(filePath, subject: subject);
    if (!child) ref.read(navStoreProvider.notifier).goToPlayback();
  } catch (error) {
    if (context.mounted) await BtInfobar.error(context, error.toString());
  }
}

Future<XFile?> pickPlaybackFile() => openFile(
  acceptedTypeGroups: [
    const XTypeGroup(
      label: '视频',
      extensions: [
        'mp4',
        'mkv',
        'avi',
        'mov',
        'webm',
        'm4v',
        'ts',
        'm2ts',
        'wmv',
        'flv',
        'mpg',
        'mpeg',
        'ogv',
      ],
    ),
  ],
);

Future<void> resumeLocalPlayback(
  BuildContext context,
  WidgetRef ref,
  PlaybackItem item,
) async {
  await openLocalPlayback(context, ref, item.filePath, subject: item.subject);
}
