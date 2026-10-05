// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:crypto/crypto.dart';

/// Versioned configuration. Unknown fields and versions survive round trips.
class RssSourceConfig {
  RssSourceConfig([Map<String, dynamic>? value])
    : values = Map.unmodifiable(value ?? const {'version': 1});

  factory RssSourceConfig.decode(String value) {
    var decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('RSS source configuration must be an object');
    }
    return RssSourceConfig(decoded);
  }

  final Map<String, dynamic> values;
  int? get version =>
      values['version'] is int ? values['version'] as int : null;
  String? get authScope =>
      values['authScope'] is String ? values['authScope'] as String : null;
  bool get isSupported =>
      version == 1 &&
      (values['authScope'] == null || values['authScope'] is String);
  String encode() => jsonEncode(values);
}

/// Full request identity, independent of the Bangumi subject and release keys.
class FeedIdentity {
  const FeedIdentity._(this.url, this.feedKey, this.provider, this.isValid);

  final String url;
  final String feedKey;
  final String provider;
  final bool isValid;

  static const mikanMirrorHosts = {'mikanani.me', 'mikanani.kas.pub'};

  static FeedIdentity fromUrl(
    String input, {
    int? legacyBmfId,
    RssSourceConfig? config,
    Set<String> equivalentMikanHosts = mikanMirrorHosts,
  }) {
    var url = input.trim();
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } on FormatException {
      uri = null;
    }
    var valid =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        !RegExp(r'\s').hasMatch(url) &&
        !RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(url);
    if (!valid) {
      return FeedIdentity._(
        url,
        'unresolved:v1:${_hash([legacyBmfId, url])}',
        'generic',
        false,
      );
    }
    var parsed = uri;
    var mikan =
        equivalentMikanHosts.contains(parsed.host) &&
        const {'/RSS/Bangumi', '/RSS/MyBangumi'}.contains(parsed.path);
    var provider = mikan
        ? 'mikan'
        : parsed.host == 'anibt.net' && parsed.path.startsWith('/rss/')
        ? 'anibt'
        : const {
                'www.comicat.org',
                'comicat.org',
                'www.kisssub.org',
                'kisssub.org',
              }.contains(parsed.host) &&
              parsed.path.endsWith('.xml')
        ? 'comicat'
        : 'generic';
    var canonical = url;
    // Replace only the host bytes. Uri.replace would also re-encode parts of
    // custom queries, losing the identity of repeated/ordered parameters.
    if (mikan && parsed.userInfo.isEmpty && !parsed.hasPort) {
      var authority = RegExp(r'^(https?://)([^/\?#]+)').firstMatch(url)!;
      canonical =
          '${authority.group(1)}mikanani.me'
          '${url.substring(authority.end)}';
    }
    return FeedIdentity._(
      url,
      'rss:v1:${_hash([canonical, config?.authScope ?? ''])}',
      provider,
      true,
    );
  }

  static String _hash(Object? value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();
}
