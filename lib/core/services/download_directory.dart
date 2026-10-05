// Dart imports:
import 'dart:io';

// Package imports:
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> defaultDownloadDirectory() async =>
    (await getDownloadsDirectory())?.path;

/// Open the current download directory, or the system Downloads directory.
Future<String?> pickDownloadDirectory({String? currentPath}) async {
  var initialDirectory = currentPath?.trim();
  if (initialDirectory == null ||
      initialDirectory.isEmpty ||
      !await Directory(initialDirectory).exists()) {
    initialDirectory = await defaultDownloadDirectory();
  }
  return getDirectoryPath(initialDirectory: initialDirectory);
}
