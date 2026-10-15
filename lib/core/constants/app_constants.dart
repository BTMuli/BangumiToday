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
  static const String bangumiVipSiteBaseUrl = 'https://bangumi.vip';
  static const String bangumiVipApiBaseUrl = 'https://api.bangumi.vip';
  static const String bangumiVipImageBaseUrl = 'https://lain.bangumi.vip';
  static const String bangumiVipFastBaseUrl = 'https://fast.bangumi.vip';
  static const String bangumiVipNextBaseUrl = 'https://next.bangumi.vip';
  static const String bangumiVipDoujinBaseUrl = 'https://doujin.bangumi.vip';
  static const String bgmApiBaseUrl = 'https://api.bgmapi.com';
  static const String anibtBangumiSiteBaseUrl = 'https://bgmmi.anibt.net';
  static const String anibtBangumiApiBaseUrl = 'https://bgmapi.anibt.net';
  static const String anibtBangumiImageBaseUrl = 'https://bgmimg.anibt.net';
  static const String defaultBangumiApiBaseUrl = bgmApiBaseUrl;
  static const String officialBangumiSiteBaseUrl = 'https://bgm.tv';
  static const String officialBangumiApiBaseUrl = 'https://api.bgm.tv';
  static const String officialBangumiImageBaseUrl = 'https://lain.bgm.tv';
  static const String officialBangumiFastBaseUrl = 'https://fast.bgm.tv';
  static const String officialBangumiNextBaseUrl = 'https://next.bgm.tv';
  static const String officialBangumiDoujinBaseUrl = 'https://doujin.bgm.tv';

  static String normalizeBangumiApiUrl(String? value) {
    var normalized = value == null ? '' : _normalizeUrl(value);
    if (normalized == 'https://api.bangumi.pro') {
      return bangumiVipApiBaseUrl;
    }
    if (normalized == bangumiVipApiBaseUrl ||
        normalized == bgmApiBaseUrl ||
        normalized == anibtBangumiApiBaseUrl ||
        normalized == officialBangumiApiBaseUrl) {
      return normalized;
    }
    return defaultBangumiApiBaseUrl;
  }

  static String bangumiSiteBaseUrlFor(String apiBaseUrl) {
    return switch (normalizeBangumiApiUrl(apiBaseUrl)) {
      anibtBangumiApiBaseUrl => anibtBangumiSiteBaseUrl,
      bgmApiBaseUrl => officialBangumiSiteBaseUrl,
      officialBangumiApiBaseUrl => officialBangumiSiteBaseUrl,
      _ => bangumiVipSiteBaseUrl,
    };
  }

  static String bangumiImageBaseUrlFor(String apiBaseUrl) {
    return switch (normalizeBangumiApiUrl(apiBaseUrl)) {
      anibtBangumiApiBaseUrl => anibtBangumiImageBaseUrl,
      bgmApiBaseUrl => officialBangumiImageBaseUrl,
      officialBangumiApiBaseUrl => officialBangumiImageBaseUrl,
      _ => bangumiVipImageBaseUrl,
    };
  }

  static String bangumiNextBaseUrlFor(String apiBaseUrl) {
    return normalizeBangumiApiUrl(apiBaseUrl) == bangumiVipApiBaseUrl
        ? bangumiVipNextBaseUrl
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
    // 已缓存的镜像链接也要跟随当前站点。
    switch (uri.host) {
      case 'bgm.tv':
      case 'bangumi.tv':
      case 'chii.in':
      case 'bangumi.pro':
      case 'bangumi.vip':
      case 'bgmmi.anibt.net':
        host = Uri.parse(bangumiSiteBaseUrlFor(normalized)).host;
        break;
      case 'api.bgm.tv':
      case 'api.bangumi.pro':
      case 'api.bangumi.vip':
      case 'api.bgmapi.com':
      case 'bgmapi.anibt.net':
        host = Uri.parse(normalized).host;
        break;
      case 'lain.bgm.tv':
      case 'lain.bangumi.pro':
      case 'lain.bangumi.vip':
      case 'bgmimg.anibt.net':
        host = Uri.parse(bangumiImageBaseUrlFor(normalized)).host;
        break;
      case 'fast.bgm.tv':
      case 'fast.bangumi.pro':
      case 'fast.bangumi.vip':
        host = Uri.parse(
          normalized == bangumiVipApiBaseUrl
              ? bangumiVipFastBaseUrl
              : officialBangumiFastBaseUrl,
        ).host;
        break;
      case 'next.bgm.tv':
      case 'next.bangumi.pro':
      case 'next.bangumi.vip':
        host = Uri.parse(bangumiNextBaseUrlFor(normalized)).host;
        break;
      case 'doujin.bgm.tv':
      case 'doujin.bangumi.pro':
      case 'doujin.bangumi.vip':
        host = Uri.parse(
          normalized == bangumiVipApiBaseUrl
              ? bangumiVipDoujinBaseUrl
              : officialBangumiDoujinBaseUrl,
        ).host;
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
