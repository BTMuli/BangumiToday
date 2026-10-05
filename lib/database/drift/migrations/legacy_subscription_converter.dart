// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:crypto/crypto.dart';

// Project imports:
import '../../../data/parsers/rss_parser.dart';
import '../../../domain/rss/feed_identity.dart';
import '../../../domain/rss/rss_item_key.dart';

typedef LegacyRow = Map<String, dynamic>;

/// A complete conversion result. No database writes or network access.
class LegacySubscriptionConversion {
  final List<LegacyRow> bmf = [];
  final List<LegacyRow> subscriptions = [];
  final List<LegacyRow> caches = [];
  final List<LegacyRow> recovery = [];
  final Map<int, int> subscriptionIdsByBmfId = {};
  final Map<String, String> rssDisposition = {};
  int discardedEmptyCaches = 0;
}

class LegacySubscriptionConverter {
  LegacySubscriptionConverter({required this.createdAt});

  final int createdAt;

  LegacySubscriptionConversion convert({
    required List<LegacyRow> bmfRows,
    required List<LegacyRow> rssRows,
    required Set<String> bmfColumns,
    required Set<String> rssColumns,
  }) {
    var result = LegacySubscriptionConversion();
    var ids = <int>{};
    var subjects = <int>{};
    var originals = <int, LegacyRow>{};
    void archive(
      String table,
      Object key,
      LegacyRow row,
      List<String> reasons,
      Iterable<int> candidates,
    ) {
      if (reasons.isEmpty) return;
      var legacyKey = '$table:${sha256.convert(utf8.encode('$key'))}';
      var existing = result.recovery.where((r) => r['legacyKey'] == legacyKey);
      if (existing.isNotEmpty) {
        var payload = jsonDecode(existing.first['payload'] as String) as Map;
        var merged = {...(payload['reasons'] as List), ...reasons}.toList();
        payload['reasons'] = merged;
        existing.first['payload'] = jsonEncode(payload);
        var old =
            jsonDecode(existing.first['candidateBmfIds'] as String) as List;
        existing.first['candidateBmfIds'] = jsonEncode(
          {...old, ...candidates}.toList()..sort(),
        );
        return;
      }
      result.recovery.add({
        'migrationVersion': 2,
        'kind': table,
        'legacyKey': legacyKey,
        'payload': jsonEncode({'row': row, 'reasons': reasons}),
        'candidateBmfIds': jsonEncode(candidates.toSet().toList()..sort()),
        'createdAt': createdAt,
        'resolvedAt': null,
      });
    }

    var ordered = List<LegacyRow>.of(bmfRows)
      ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    for (var row in ordered) {
      var id = row['id'];
      var subject = row['subject'];
      if (id is! int ||
          subject is! int ||
          !ids.add(id) ||
          !subjects.add(subject)) {
        throw StateError('Legacy AppBmf identity is missing or duplicated');
      }
      originals[id] = row;
      result.bmf.add({
        'id': id,
        'subject': subject,
        'title': bmfColumns.contains('title') ? row['title'] : '',
        'airDate': bmfColumns.contains('airDate') ? row['airDate'] : '',
        'download': row['download'],
      });
      var reasons = <String>[];
      var url = row['rss'] as String? ?? '';
      var mkId = row['mkBgmId'] as String?;
      var mkGroup = row['mkGroupId'] as String?;
      var rawAuto = bmfColumns.contains('autoUpdate') ? row['autoUpdate'] : 1;
      if (!bmfColumns.contains('autoUpdate')) reasons.add('missingAutoUpdate');
      if (rawAuto is! int) {
        throw StateError('Legacy AppBmf autoUpdate has an invalid type');
      }
      if (rawAuto != 0 && rawAuto != 1) reasons.add('nonBooleanAutoUpdate');
      if (url.trim().isEmpty) {
        if ((mkId?.isNotEmpty ?? false) || (mkGroup?.isNotEmpty ?? false)) {
          reasons.add('mikanFieldsWithoutUrl');
        }
        archive('AppBmf', id, row, reasons, [id]);
        continue;
      }
      var identity = FeedIdentity.fromUrl(url, legacyBmfId: id);
      if (!identity.isValid) reasons.add('invalidUrl');
      if (_mikanConflict(identity, mkId, mkGroup)) {
        reasons.add('urlMikanConflict');
      }
      var subscriptionId = result.subscriptions.length + 1;
      result.subscriptionIdsByBmfId[id] = subscriptionId;
      result.subscriptions.add({
        'id': subscriptionId,
        'bmfId': id,
        'provider': identity.provider,
        'url': identity.url,
        'feedKey': identity.feedKey,
        'sourceConfig': '{"version":1}',
        'autoUpdate': rawAuto == 0 ? 0 : 1,
        'status': identity.isValid ? 'active' : 'needsReview',
        'pendingItems': '[]',
        'knownItems': '[]',
        'hasBaseline': 0,
        'itemKeyVersion': rssItemKeyVersion,
      });
      archive('AppBmf', id, row, reasons, [id]);
    }

    var cacheByKey = <String, LegacyRow>{};
    var selectedTimes = <String, int>{};
    var seenRss = <String>{};
    for (var row in rssRows) {
      var url = row['rss'];
      if (url is! String || !seenRss.add(url)) {
        throw StateError('Legacy AppRss identity is missing or duplicated');
      }
      var reasons = <String>[];
      var identity = FeedIdentity.fromUrl(url);
      var matching = result.subscriptions
          .where((s) => identity.isValid && s['feedKey'] == identity.feedKey)
          .toList();
      var candidates = matching.map((s) => s['bmfId'] as int).toSet();
      var mkId = row['mkBgmId'] as String?;
      if (matching.isEmpty && (mkId?.isNotEmpty ?? false)) {
        candidates.addAll(
          originals.entries
              .where((e) => e.value['mkBgmId'] == mkId)
              .map((e) => e.key),
        );
      }
      Set<String> pending;
      try {
        pending = _keys(
          rssColumns.contains('pendingItems') ? row['pendingItems'] : '[]',
        );
      } on FormatException {
        pending = {};
        reasons.add('invalidPendingJson');
      }
      var conflict = _mikanConflict(
        identity,
        mkId,
        row['mkGroupId'] as String?,
      );
      if (conflict) reasons.add('cacheMikanConflict');
      if (matching.isEmpty) {
        if (candidates.isNotEmpty) reasons.add('ambiguousCacheOwnership');
        if (pending.isNotEmpty) reasons.add('orphanPending');
        if (reasons.isEmpty) result.discardedEmptyCaches++;
      }
      if (conflict ||
          matching.isEmpty ||
          reasons.contains('invalidPendingJson')) {
        for (var s in result.subscriptions) {
          if (candidates.contains(s['bmfId'])) s['status'] = 'needsReview';
        }
        archive('AppRss', url, row, reasons, candidates);
        result.rssDisposition[url] = reasons.isEmpty
            ? 'discardedEmpty'
            : 'recovery';
        if (conflict || matching.isEmpty) continue;
      }
      var data = row['data'] as String?;
      var version = rssColumns.contains('cacheVersion')
          ? row['cacheVersion']
          : 1;
      var known = <String>{};
      var usable = false;
      if (data != null && data.isNotEmpty && version == 1) {
        try {
          known = RssFeed.parse(data).items.map(rssItemKey).toSet();
          usable = true;
        } on FormatException {
          reasons.add('invalidXml');
        }
      } else if (data != null && data.isNotEmpty) {
        reasons.add('incompatibleCacheVersion');
      }
      int time(String column) {
        var value = row[column] ?? 0;
        if (value is! int || value < 0) {
          reasons.add('invalidTime:$column');
          return 0;
        }
        return value;
      }

      var success = usable ? time('updated') : 0;
      var failed = time('lastFailed');
      var attempt = success > failed ? success : failed;
      if (failed <= success) failed = 0;
      var ttl = row['ttl'];
      var ttlMinutes = ttl is int && ttl > 0 ? ttl : 0;
      if (usable && success >= (selectedTimes[identity.feedKey] ?? -1)) {
        selectedTimes[identity.feedKey] = success;
        cacheByKey[identity.feedKey] = {
          'feedKey': identity.feedKey,
          'requestUrl': identity.url,
          'data': data,
          'ttlMinutes': ttlMinutes,
          'lastSuccessAt': success,
          'lastAttemptAt': attempt,
          'lastFailedAt': failed,
          'cacheVersion': 1,
        };
        for (var s in matching) {
          s['knownItems'] = jsonEncode(known.toList()..sort());
          s['hasBaseline'] = 1;
        }
      } else if (!cacheByKey.containsKey(identity.feedKey)) {
        cacheByKey[identity.feedKey] = {
          'feedKey': identity.feedKey,
          'requestUrl': identity.url,
          'data': null,
          'ttlMinutes': ttlMinutes,
          'lastSuccessAt': 0,
          'lastAttemptAt': attempt,
          'lastFailedAt': failed,
          'cacheVersion': 1,
        };
      }
      for (var s in matching) {
        s['pendingItems'] = jsonEncode(
          {..._keys(s['pendingItems']), ...pending}.toList()..sort(),
        );
      }
      var cache = cacheByKey[identity.feedKey]!;
      if (attempt > (cache['lastAttemptAt'] as int)) {
        cache['lastAttemptAt'] = attempt;
      }
      if (failed > (cache['lastFailedAt'] as int)) {
        cache['lastFailedAt'] = failed;
      }
      if ((cache['lastFailedAt'] as int) <= (cache['lastSuccessAt'] as int)) {
        cache['lastFailedAt'] = 0;
      }
      archive('AppRss', url, row, reasons, candidates);
      result.rssDisposition[url] = reasons.isEmpty
          ? 'converted'
          : 'convertedAndRecovery';
    }
    result.caches.addAll(cacheByKey.values);
    return result;
  }

  static Set<String> _keys(Object? value) {
    if (value is! String) throw const FormatException('Invalid item keys');
    var decoded = jsonDecode(value);
    if (decoded is! List || decoded.any((e) => e is! String)) {
      throw const FormatException('Invalid item keys');
    }
    return decoded.cast<String>().toSet();
  }

  static bool _mikanConflict(FeedIdentity identity, String? id, String? group) {
    if (!(id?.isNotEmpty ?? false) && !(group?.isNotEmpty ?? false)) {
      return false;
    }
    if (!identity.isValid || identity.provider != 'mikan') return true;
    var parameters = Uri.parse(identity.url).queryParameters;
    return (id?.isNotEmpty == true && parameters['bangumiId'] != id) ||
        (group?.isNotEmpty == true && parameters['subgroupid'] != group);
  }
}
