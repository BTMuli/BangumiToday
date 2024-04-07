
import 'dart:math';

/// bytes2size
String bytes2size(int bytes) {
  if (bytes == 0) return '0B';
  const k = 1024;
  final sizes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
  final i = (log(bytes) / log(k)).floor();
  return '${(bytes / pow(k, i)).toStringAsFixed(2)} ${sizes[i]}';
}

/// date trans
/// 2021-08-01T00:00:00.000 => 2021-08-01 00:00:00
String dateTransMikan(String date) {
  return date.replaceAll('T', ' ').substring(0, 19);
}