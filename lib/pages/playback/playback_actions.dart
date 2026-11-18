// Dart imports:
import 'dart:io';

// Package imports:
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../core/services/playback_subtitle_files.dart';
import '../../core/services/playback_window_service.dart';
import '../../models/playback/playback_item.dart';
import '../../providers/playback_window_providers.dart';
import '../../store/nav_store.dart';
import '../../store/playback_store.dart';
import '../../ui/bt_dialog.dart';
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

Future<void> importPlaybackSubtitleDirectories(
  BuildContext context,
  PlaybackStore store,
  List<String> directories,
) async {
  var playlist = store.playlist;
  var result = await store.importSubtitleDirectories(directories);
  if (result == null || !context.mounted || store.isClosed) return;
  if (result.matches.isEmpty && result.files.isNotEmpty) {
    var preview = PlaybackSubtitleFiles.match(
      result.files,
      playlist,
      matchByEpisode: true,
    );
    if (preview.matches.isNotEmpty) {
      var example = preview.matches.entries.first;
      var video = playlist.firstWhere((item) => item.key == example.key);
      var confirmed = await showConfirmAction(
        context,
        title: '按集数匹配字幕',
        content:
            '字幕与视频的片名不同，可按集数匹配 ${preview.matchedFiles} 个字幕'
            '到 ${preview.matches.length} 个视频。请确认它们属于同一部作品。\n\n'
            '字幕：${path.basename(example.value.first)}\n\n'
            '视频：${path.basename(video.filePath)}',
        confirmText: '按集数导入',
      );
      if (!context.mounted || !confirmed || store.isClosed) return;
      if (!identical(store.playlist, playlist)) {
        await BtInfobar.warn(context, '播放列表已切换，请重新导入字幕目录');
        return;
      }
      result = await store.importSubtitleDirectories(
        directories,
        matchByEpisode: true,
      );
      if (result == null || !context.mounted || store.isClosed) return;
    }
  }
  if (result.files.isEmpty) {
    await BtInfobar.warn(context, '所选目录及子目录中没有支持的字幕文件');
  } else if (result.matches.isEmpty) {
    await BtInfobar.warn(context, '未找到匹配的字幕，请检查字幕文件名与视频文件名或集数');
  } else {
    var skipped = result.unmatchedFiles;
    await BtInfobar.success(
      context,
      '已导入 ${result.matchedFiles} 个字幕，匹配 ${result.matches.length} 个视频'
      '${skipped == 0 ? '' : '，跳过 $skipped 个未匹配字幕'}',
    );
  }
}

Future<void> resumeLocalPlayback(
  BuildContext context,
  WidgetRef ref,
  PlaybackItem item,
) async {
  await openLocalPlayback(context, ref, item.filePath, subject: item.subject);
}
