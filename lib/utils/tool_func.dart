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

/// 转成本地时间
/// 2024-04-13T01:04:47+08:00 => 2024-04-13 21:04:47
String dateTransLocal(String date) {
  return DateTime.parse(date).toLocal().toString().substring(0, 19);
}
