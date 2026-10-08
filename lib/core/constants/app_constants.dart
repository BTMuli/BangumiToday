class BTAppConstants {
  BTAppConstants._();

  static const String appName = 'BangumiToday';
  static const String appLink = 'https://github.com/BTMuli/BangumiToday';

  static const String urlScheme = 'bangumitoday';
  static const String subjectPath = 'subject';
  static const String bangumiOauthRedirectUri =
      'BangumiToday://oauth/bangumi/callback';

  static const double defaultWindowWidth = 1280;
  static const double defaultWindowHeight = 720;

  static const String officialMikanMirror = 'https://mikanani.me';
  static const String defaultMikanMirror = 'https://mikanani.kas.pub';
  static const List<String> mikanMirrors = [
    defaultMikanMirror,
    officialMikanMirror,
  ];
  static const Set<String> mikanHosts = {
    'mikanani.me',
    'mikanime.tv',
    'mikanani.hacgn.fun',
    'mikanani.kas.pub',
  };
  static const String bangumiProSiteBaseUrl = 'https://bangumi.pro';
  static const String bangumiProApiBaseUrl = 'https://api.bangumi.pro';
  static const String bangumiProImageBaseUrl = 'https://lain.bangumi.pro';
  static const String bangumiProFastBaseUrl = 'https://fast.bangumi.pro';
  static const String bangumiProNextBaseUrl = 'https://next.bangumi.pro';
  static const String bangumiProDoujinBaseUrl = 'https://doujin.bangumi.pro';
  static const String defaultBangumiApiBaseUrl = bangumiProApiBaseUrl;
  static const String officialBangumiSiteBaseUrl = 'https://bgm.tv';
  static const String officialBangumiApiBaseUrl = 'https://api.bgm.tv';
  static const String officialBangumiImageBaseUrl = 'https://lain.bgm.tv';
  static const String officialBangumiFastBaseUrl = 'https://fast.bgm.tv';
  static const String officialBangumiNextBaseUrl = 'https://next.bgm.tv';
  static const String officialBangumiDoujinBaseUrl = 'https://doujin.bgm.tv';

  static String normalizeBangumiApiUrl(String? value) {
    var normalized = value == null ? '' : _normalizeUrl(value);
    if (normalized == bangumiProApiBaseUrl ||
        normalized == officialBangumiApiBaseUrl) {
      return normalized;
    }
    return defaultBangumiApiBaseUrl;
  }

  static String bangumiSiteBaseUrlFor(String apiBaseUrl) {
    return switch (normalizeBangumiApiUrl(apiBaseUrl)) {
      officialBangumiApiBaseUrl => officialBangumiSiteBaseUrl,
      _ => bangumiProSiteBaseUrl,
    };
  }

  static String bangumiImageBaseUrlFor(String apiBaseUrl) {
    return switch (normalizeBangumiApiUrl(apiBaseUrl)) {
      officialBangumiApiBaseUrl => officialBangumiImageBaseUrl,
      _ => bangumiProImageBaseUrl,
    };
  }

  static String bangumiNextBaseUrlFor(String apiBaseUrl) {
    return normalizeBangumiApiUrl(apiBaseUrl) == bangumiProApiBaseUrl
        ? bangumiProNextBaseUrl
        : officialBangumiNextBaseUrl;
  }

  static String mikanMirrorLabel(String value) {
    if (value == officialMikanMirror) return 'mikanani.me（官方）';
    if (value == defaultMikanMirror) return 'mikanani.kas.pub';
    var host = Uri.tryParse(value)?.host;
    if (host == null || host.isEmpty) return value;
    return host;
  }

  static List<String> mikanMirrorChoices(String current) {
    var values = [...mikanMirrors];
    var normalized = normalizeMikanUrl(current);
    if (!values.contains(normalized)) values.add(normalized);
    return values;
  }

  static bool isMikanHost(String host) {
    var normalized = host.toLowerCase();
    if (normalized.startsWith('www.')) {
      normalized = normalized.substring(4);
    }
    return mikanHosts.contains(normalized);
  }

  static String normalizeMikanUrl(String? value) {
    if (value == null || value.trim().isEmpty) return defaultMikanMirror;
    var normalized = _normalizeUrl(value);
    return normalized.isEmpty ? defaultMikanMirror : normalized;
  }

  static String rewriteMikanUrl(String value, String mikanBaseUrl) {
    var uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return value;
    if (uri.scheme != 'http' && uri.scheme != 'https') return value;
    if (!isMikanHost(uri.host)) return value;

    var targetUri = Uri.parse(normalizeMikanUrl(mikanBaseUrl));
    if (uri.scheme == targetUri.scheme && uri.host == targetUri.host) {
      return value;
    }
    return uri
        .replace(scheme: targetUri.scheme, host: targetUri.host)
        .toString();
  }

  static String rewriteBangumiUrl(String value, String apiBaseUrl) {
    var uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return value;

    var normalized = normalizeBangumiApiUrl(apiBaseUrl);
    String? host;
    // 已缓存的旧镜像链接也要跟随当前站点。
    switch (uri.host) {
      case 'bgm.tv':
      case 'bangumi.tv':
      case 'chii.in':
      case 'bgmmi.anibt.net':
        host = Uri.parse(bangumiSiteBaseUrlFor(normalized)).host;
        break;
      case 'api.bgm.tv':
      case 'bgmapi.anibt.net':
        host = Uri.parse(normalized).host;
        break;
      case 'lain.bgm.tv':
      case 'bgmimg.anibt.net':
        host = Uri.parse(bangumiImageBaseUrlFor(normalized)).host;
        break;
      case 'fast.bgm.tv':
        if (normalized == bangumiProApiBaseUrl) {
          host = Uri.parse(bangumiProFastBaseUrl).host;
        }
        break;
      case 'next.bgm.tv':
        if (normalized == bangumiProApiBaseUrl) {
          host = Uri.parse(bangumiProNextBaseUrl).host;
        }
        break;
      case 'doujin.bgm.tv':
        if (normalized == bangumiProApiBaseUrl) {
          host = Uri.parse(bangumiProDoujinBaseUrl).host;
        }
        break;
    }
    if (host == null) return value;
    return uri.replace(scheme: 'https', host: host).toString();
  }

  static String _normalizeUrl(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  static const int defaultRequestTimeout = 30000;
  static const int defaultPageLimit = 10;

  static const List<String> weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  static const List<String> ratingLabels = [
    '不忍直视',
    '很差',
    '差',
    '较差',
    '不过不失',
    '还行',
    '推荐',
    '力荐',
    '神作',
    '超神作',
  ];

  static String getRatingLabel(double rate) {
    var index = rate.floor() - 1;
    if (index < 0) index = 0;
    if (index > 9) index = 9;
    return ratingLabels[index];
  }
}
