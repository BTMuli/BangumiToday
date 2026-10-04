// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

/// A local video and its optional Bangumi association.
class PlaybackItem {
  const PlaybackItem({
    required this.filePath,
    required this.title,
    this.subject,
    this.sizeBytes,
    this.positionMs = 0,
    this.durationMs = 0,
    this.completed = false,
    this.updatedAt = 0,
  });

  final String filePath;
  final String title;
  final int? subject;

  /// File metadata from the latest library scan; not persisted in history.
  final int? sizeBytes;
  final int positionMs;
  final int durationMs;
  final bool completed;
  final int updatedAt;

  static String pathKey(String value) {
    var normalized = path.normalize(path.absolute(value));
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  String get key => pathKey(filePath);

  Duration get resumePosition => completed
      ? Duration.zero
      : Duration(
          milliseconds: positionMs.clamp(
            0,
            durationMs > 0 ? durationMs : positionMs,
          ),
        );

  factory PlaybackItem.fromRow(Map<String, Object?> row) => PlaybackItem(
    filePath: row['filePath'] as String,
    title: row['title'] as String,
    subject: row['subject'] as int?,
    positionMs: row['positionMs'] as int,
    durationMs: row['durationMs'] as int,
    completed: row['completed'] == 1,
    updatedAt: row['updatedAt'] as int,
  );

  Map<String, Object?> toRow() => {
    'pathKey': key,
    'filePath': filePath,
    'title': title,
    'subject': subject,
    'positionMs': positionMs,
    'durationMs': durationMs,
    'completed': completed ? 1 : 0,
    'updatedAt': updatedAt,
  };
}
