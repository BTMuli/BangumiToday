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
  static const String anibtBangumiSiteBaseUrl = 'https://bgmmi.anibt.net';
  static const String anibtBangumiApiBaseUrl = 'https://bgmapi.anibt.net';
  static const String anibtBangumiImageBaseUrl = 'https://bgmimg.anibt.net';
  static const String bgmapiBangumiApiBaseUrl = 'https://api.bgmapi.com';
  static const String defaultBangumiApiBaseUrl = officialBangumiApiBaseUrl;
  static const String defaultBangumiSiteBaseUrl = bangumiVipSiteBaseUrl;
  static const String defaultBangumiImageBaseUrl = anibtBangumiImageBaseUrl;
  static const String officialBangumiSiteBaseUrl = 'https://bgm.tv';
  static const String officialBangumiApiBaseUrl = 'https://api.bgm.tv';
  static const String officialBangumiImageBaseUrl = 'https://lain.bgm.tv';
  static const String officialBangumiFastBaseUrl = 'https://fast.bgm.tv';
  static const String officialBangumiNextBaseUrl = 'https://next.bgm.tv';
  static const String officialBangumiDoujinBaseUrl = 'https://doujin.bgm.tv';

  /// 镜像以 HTTP/HTTPS 域名和可选端口为单位，不接受路径或凭据。
  static String? normalizeBangumiMirrorOrigin(String? value) {
    var text = value?.trim() ?? '';
    if (text.isEmpty || RegExp(r'\s').hasMatch(text)) return null;
    var uri = Uri.tryParse(text);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port < 1 ||
        uri.port > 65535) {
      return null;
    }
    return uri.origin;
  }

  static String normalizeBangumiApiUrl(String? value) {
    var normalized = normalizeBangumiMirrorOrigin(value);
    if (normalized == 'https://api.bangumi.pro') {
      return bangumiVipApiBaseUrl;
    }
    return normalized ?? defaultBangumiApiBaseUrl;
  }

  static String bangumiSiteBaseUrlFor(String apiBaseUrl) {
    return switch (normalizeBangumiApiUrl(apiBaseUrl)) {
      anibtBangumiApiBaseUrl => anibtBangumiSiteBaseUrl,
      bangumiVipApiBaseUrl => bangumiVipSiteBaseUrl,
      _ => officialBangumiSiteBaseUrl,
    };
  }

  static String normalizeBangumiSiteUrl(String? value) {
    var normalized = normalizeBangumiMirrorOrigin(value);
    if (normalized == 'https://bangumi.pro') return bangumiVipSiteBaseUrl;
    return normalized ?? defaultBangumiSiteBaseUrl;
  }

  static String bangumiImageBaseUrlFor(String apiBaseUrl) {
    return switch (normalizeBangumiApiUrl(apiBaseUrl)) {
      anibtBangumiApiBaseUrl => anibtBangumiImageBaseUrl,
      bangumiVipApiBaseUrl => bangumiVipImageBaseUrl,
      _ => officialBangumiImageBaseUrl,
    };
  }

  static String normalizeBangumiImageUrl(String? value) {
    var normalized = normalizeBangumiMirrorOrigin(value);
    if (normalized == 'https://lain.bangumi.pro') {
      return bangumiVipImageBaseUrl;
    }
    return normalized ?? defaultBangumiImageBaseUrl;
  }

  static String bangumiNextBaseUrlFor(String apiBaseUrl) {
    return normalizeBangumiApiUrl(apiBaseUrl) == bangumiVipApiBaseUrl
        ? bangumiVipNextBaseUrl
        : officialBangumiNextBaseUrl;
  }

  static String bangumiPrivateApiBaseUrlFor(String apiBaseUrl) {
    var normalized = normalizeBangumiApiUrl(apiBaseUrl);
    return normalized == officialBangumiApiBaseUrl
        ? officialBangumiNextBaseUrl
        : normalized;
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

  static String rewriteBangumiUrl(
    String value, {
    required String apiBaseUrl,
    required String siteBaseUrl,
    required String imageBaseUrl,
    Iterable<String> siteMirrorUrls = const [],
    Iterable<String> apiMirrorUrls = const [],
    Iterable<String> imageMirrorUrls = const [],
  }) {
    var uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return value;
    if (uri.scheme != 'http' && uri.scheme != 'https') return value;

    var normalized = normalizeBangumiApiUrl(apiBaseUrl);
    var site = normalizeBangumiSiteUrl(siteBaseUrl);
    var image = normalizeBangumiImageUrl(imageBaseUrl);
    String? target;
    // 已缓存的镜像链接也要跟随当前站点。
    switch (uri.host) {
      case 'bgm.tv':
      case 'bangumi.tv':
      case 'chii.in':
      case 'bangumi.pro':
      case 'bangumi.vip':
      case 'bgmmi.anibt.net':
        target = site;
        break;
      case 'api.bgm.tv':
      case 'api.bangumi.pro':
      case 'api.bangumi.vip':
      case 'api.bgmapi.com':
      case 'bgmapi.anibt.net':
        target = normalized;
        break;
      case 'lain.bgm.tv':
      case 'lain.bangumi.pro':
      case 'lain.bangumi.vip':
      case 'bgmimg.anibt.net':
        target = image;
        break;
      case 'fast.bgm.tv':
      case 'fast.bangumi.pro':
      case 'fast.bangumi.vip':
        target = image == bangumiVipImageBaseUrl
            ? bangumiVipFastBaseUrl
            : officialBangumiFastBaseUrl;
        break;
      case 'next.bgm.tv':
      case 'next.bangumi.pro':
      case 'next.bangumi.vip':
        target = bangumiNextBaseUrlFor(normalized);
        break;
      case 'doujin.bgm.tv':
      case 'doujin.bangumi.pro':
      case 'doujin.bangumi.vip':
        target = site == bangumiVipSiteBaseUrl
            ? bangumiVipDoujinBaseUrl
            : officialBangumiDoujinBaseUrl;
        break;
    }
    if (target == null) {
      var origin = uri.origin;
      var isSite = siteMirrorUrls.contains(origin);
      var isApi = apiMirrorUrls.contains(origin);
      var isImage = imageMirrorUrls.contains(origin);
      if (isImage && RegExp(r'^/(pic|r|img)(/|$)').hasMatch(uri.path)) {
        target = image;
      } else if (isApi &&
          RegExp(r'^/(v0|v2|calendar|search)(/|$)').hasMatch(uri.path)) {
        target = normalized;
      } else if (isSite) {
        target = site;
      } else if (isApi) {
        target = normalized;
      } else if (isImage) {
        target = image;
      }
    }
    if (target == null) return value;
    var destination = Uri.parse(target);
    return uri
        .replace(
          scheme: destination.scheme,
          host: destination.host,
          port: destination.port,
          userInfo: '',
        )
        .toString();
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
