// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:crypto/crypto.dart';

/// Invalid historical JSON stays intact; it contributes no searchable title.
(String, String) collectionTitles(String? subject) {
  try {
    var json = jsonDecode(subject ?? 'null');
    if (json is Map) {
      return (
        json['name'] is String ? json['name'] as String : '',
        json['name_cn'] is String ? json['name_cn'] as String : '',
      );
    }
  } on FormatException {
    // Preserve the original cache for diagnosis or a later API refresh.
  }
  return ('', '');
}

/// Prefer an information site's ID because BangumiData has no global ID.
/// Qualifiers distinguish languages and broadcast runs sharing an ID.
/// Corrections to these qualifiers are reconciled by complete snapshot updates.
String? dataItemKey(Map<String, dynamic> values) {
  if (['title', 'type', 'lang', 'begin'].any((k) => values[k] is! String)) {
    return null;
  }
  const priority = ['bangumi', 'tmdb', 'anidb', 'aniList', 'mal'];
  var siteIds = <String, Set<String>>{};
  try {
    var sites = jsonDecode(values['sites'] as String? ?? '[]');
    if (sites is! List) return null;
    for (var site in sites) {
      if (site is Map &&
          priority.contains(site['site']) &&
          site['id'] is String) {
        var id = (site['id'] as String).trim();
        if (id.isNotEmpty) {
          siteIds.putIfAbsent(site['site'] as String, () => {}).add(id);
        }
      }
    }
  } on FormatException {
    return null;
  }
  var identity = <String>['title', values['title'] as String];
  for (var site in priority) {
    var ids = siteIds[site];
    if (ids == null) continue;
    identity = [site, ...(ids.toList()..sort())];
    break;
  }
  var begin = values['begin'] as String;
  var canonical = [
    identity,
    values['type'],
    values['lang'],
    DateTime.tryParse(begin)?.toUtc().toIso8601String() ?? begin,
  ];
  return 'v1:${sha256.convert(utf8.encode(jsonEncode(canonical)))}';
}
