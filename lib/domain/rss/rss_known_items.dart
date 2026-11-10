// Dart imports:
import 'dart:convert';

/// Last observation of each release; legacy string keys get a retention grace
/// period when first maintained. The stored payload remains a JSON array.
class RssKnownItems {
  RssKnownItems._(this._seen);

  static const retention = Duration(days: 14);
  final Map<String, int?> _seen;

  factory RssKnownItems.decode(String value) {
    var decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException('RSS known items must be an array');
    }
    var seen = <String, int?>{};
    for (var entry in decoded) {
      if (entry is String) {
        seen.putIfAbsent(entry, () => null);
      } else if (entry is Map &&
          entry['key'] is String &&
          entry['lastSeenAt'] is int &&
          (entry['lastSeenAt'] as int) >= 0) {
        seen[entry['key'] as String] = entry['lastSeenAt'] as int;
      } else {
        throw const FormatException('Invalid RSS known item');
      }
    }
    return RssKnownItems._(seen);
  }

  Set<String> get keys => _seen.keys.toSet();
  bool contains(String key) => _seen.containsKey(key);

  void prune(int now) {
    var cutoff = now - retention.inMilliseconds;
    _seen.updateAll((_, at) => at ?? now);
    _seen.removeWhere((_, at) => at! <= cutoff);
  }

  void observe(Iterable<String> keys, int at) {
    for (var key in keys) {
      var previous = _seen[key];
      _seen[key] = previous != null && previous > at ? previous : at;
    }
  }

  String encode() {
    var keys = _seen.keys.toList()..sort();
    return jsonEncode([
      for (var key in keys)
        if (_seen[key] == null) key else {'key': key, 'lastSeenAt': _seen[key]},
    ]);
  }
}
