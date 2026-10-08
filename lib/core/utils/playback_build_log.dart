// Dart imports:
import 'dart:convert';
import 'dart:io';

/// Read a bounded tail while the native compiler continues writing the file.
Future<List<String>> readPlaybackBuildLog(File file) async {
  var handle = await file.open();
  try {
    var size = await handle.length();
    var start = size > 65536 ? size - 65536 : 0;
    await handle.setPosition(start);
    var bytes = await handle.read(size - start);
    if (start > 0) {
      // Discard the partial first line before decoding, including split UTF-8.
      var newline = bytes.indexOf(10);
      if (newline < 0) return const [];
      bytes = bytes.sublist(newline + 1);
    }
    // A live writer may not have finished the final UTF-8 character yet.
    var end = bytes.length;
    if (end > 0) {
      var lead = end - 1;
      while (lead > 0 && bytes[lead] & 0xc0 == 0x80) {
        lead--;
      }
      var first = bytes[lead];
      var length = first & 0xe0 == 0xc0
          ? 2
          : first & 0xf0 == 0xe0
          ? 3
          : first & 0xf8 == 0xf0
          ? 4
          : 1;
      if (end - lead < length) end = lead;
    }
    return parsePlaybackBuildLog(
      utf8.decode(bytes.sublist(0, end), allowMalformed: true),
    );
  } finally {
    await handle.close();
  }
}

List<String> parsePlaybackBuildLog(String text) {
  var clean = text
      .replaceAll(RegExp(r'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)'), '')
      .replaceAll(RegExp(r'\x1b\[[0-?]*[ -/]*[@-~]'), '')
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'), '');
  var lines = clean
      .split('\n')
      // A bare carriage return replaces the terminal's current progress line.
      .map((line) => line.split('\r').last.trimRight())
      .where((line) => line.isNotEmpty)
      .toList();
  return List.unmodifiable(
    lines.skip(lines.length > 200 ? lines.length - 200 : 0),
  );
}
