/// 替换转义字符
String replaceEscape(String str) {
  return str
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');
}

/// 字节转换成KB、MB、GB
/// 之前用的是 filesize 的库，但是 archived 了，所以自己写了一个
String filesize(int bytes) {
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  var check = 0;
  double num = bytes.toDouble();
  while (num >= 1024) {
    num /= 1024;
    check++;
  }
  return '${num.toStringAsFixed(2)} ${sizes[check]}';
}

/// filesize 的 web 版本，因为网速普遍用的 b
String filesizeW(int bytes) {
  const sizes = ['b', 'Kb', 'Mb', 'Gb', 'Tb'];
  var check = 0;
  double num = bytes * 8.toDouble();
  while (num >= 1024) {
    num /= 1024;
    check++;
  }
  return '${num.toStringAsFixed(2)} ${sizes[check]}';
}
