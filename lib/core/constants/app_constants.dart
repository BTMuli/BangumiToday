class BTAppConstants {
  BTAppConstants._();

  static const String appName = 'BangumiToday';
  static const String appLink = 'https://github.com/BTMuli/BangumiToday';

  static const String urlScheme = 'bangumitoday';
  static const String subjectPath = 'subject';

  static const double defaultWindowWidth = 1280;
  static const double defaultWindowHeight = 720;

  static const String defaultMikanMirror = 'https://mikanani.me';
  static const String bangumiSiteBaseUrl = 'https://bgmmi.anibt.net';
  static const String bangumiApiBaseUrl = 'https://bgmapi.anibt.net';
  static const String bangumiImageBaseUrl = 'https://bgmimg.anibt.net';
  static const String bangumiLolSiteBaseUrl = 'https://bangumi.lol';
  static const String bangumiLolApiBaseUrl = 'https://api.bangumi.lol';
  static const String bangumiLolImageBaseUrl = 'https://lain.bangumi.lol';
  static const String bangumiLolFastBaseUrl = 'https://fast.bangumi.lol';
  static const String bangumiLolNextBaseUrl = 'https://next.bangumi.lol';
  static const String bangumiLolDoujinBaseUrl = 'https://doujin.bangumi.lol';
  static const String officialBangumiSiteBaseUrl = 'https://bgm.tv';
  static const String officialBangumiApiBaseUrl = 'https://api.bgm.tv';
  static const String officialBangumiImageBaseUrl = 'https://lain.bgm.tv';
  static const String officialBangumiFastBaseUrl = 'https://fast.bgm.tv';
  static const String officialBangumiNextBaseUrl = 'https://next.bgm.tv';
  static const String officialBangumiDoujinBaseUrl = 'https://doujin.bgm.tv';

  static String bangumiSiteBaseUrlFor(String apiBaseUrl) {
    return switch (_normalizeUrl(apiBaseUrl)) {
      officialBangumiApiBaseUrl => officialBangumiSiteBaseUrl,
      bangumiLolApiBaseUrl => bangumiLolSiteBaseUrl,
      _ => bangumiSiteBaseUrl,
    };
  }

  static String bangumiImageBaseUrlFor(String apiBaseUrl) {
    return switch (_normalizeUrl(apiBaseUrl)) {
      officialBangumiApiBaseUrl => officialBangumiImageBaseUrl,
      bangumiLolApiBaseUrl => bangumiLolImageBaseUrl,
      _ => bangumiImageBaseUrl,
    };
  }

  static String bangumiNextBaseUrlFor(String apiBaseUrl) {
    return _normalizeUrl(apiBaseUrl) == bangumiLolApiBaseUrl
        ? bangumiLolNextBaseUrl
        : officialBangumiNextBaseUrl;
  }

  static String rewriteBangumiUrl(String value, String apiBaseUrl) {
    var uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return value;

    var normalized = _normalizeUrl(apiBaseUrl);
    String? host;
    switch (uri.host) {
      case 'bgm.tv':
      case 'bangumi.tv':
      case 'chii.in':
        host = Uri.parse(bangumiSiteBaseUrlFor(normalized)).host;
        break;
      case 'api.bgm.tv':
        host = Uri.parse(normalized).host;
        break;
      case 'lain.bgm.tv':
        host = Uri.parse(bangumiImageBaseUrlFor(normalized)).host;
        break;
      case 'fast.bgm.tv':
        if (normalized == bangumiLolApiBaseUrl) {
          host = Uri.parse(bangumiLolFastBaseUrl).host;
        }
        break;
      case 'next.bgm.tv':
        if (normalized == bangumiLolApiBaseUrl) {
          host = Uri.parse(bangumiLolNextBaseUrl).host;
        }
        break;
      case 'doujin.bgm.tv':
        if (normalized == bangumiLolApiBaseUrl) {
          host = Uri.parse(bangumiLolDoujinBaseUrl).host;
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
