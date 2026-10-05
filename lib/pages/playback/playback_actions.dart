// Dart imports:
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
    await openLocalPlaybackFile(ref, filePath, subject: subject);
  } catch (error) {
    if (context.mounted) await reportPlaybackError(context, ref, error);
  }
}

/// Shared by file picking and window-wide drops, whose context is above the
/// Navigator and therefore presents operation failures outside its Overlay.
Future<void> openLocalPlaybackFile(
  WidgetRef ref,
  String filePath, {
  int? subject,
}) async {
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
}

/// Consume the stored copy before showing an operation failure. Page listeners
/// handle unattended failures on the next frame, so the same error appears
/// once.
Future<void> reportPlaybackError(
  BuildContext context,
  WidgetRef ref,
  Object error,
) async {
  await BtInfobar.error(context, consumePlaybackError(ref, error));
}

String consumePlaybackError(WidgetRef ref, Object error) {
  var message = error.toString();
  var store = ref.read(playbackStoreProvider);
  if (store.error == message) store.clearError();
  if (Platform.isWindows && !ref.read(isPlaybackWindowProvider)) {
    var windows = ref.read(playbackWindowServiceProvider);
    if (windows.error == message) windows.clearError();
  }
  return message;
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
