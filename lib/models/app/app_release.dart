// Package imports:
import 'package:pub_semver/pub_semver.dart';

// Project imports:
import '../../core/constants/app_constants.dart';

/// GitHub 正式发布版本。
class AppRelease {
  const AppRelease._(this.tag, this.version);

  final String tag;
  final Version version;

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    var tag = json['tag_name'];
    if (tag is! String || tag.trim().isEmpty) {
      throw const FormatException('发布信息缺少版本号');
    }
    tag = tag.trim();
    return AppRelease._(tag, _parseVersion(tag));
  }

  String get url =>
      '${BTAppConstants.appLink}/releases/tag/${Uri.encodeComponent(tag)}';

  bool isNewerThan(String currentVersion) =>
      version > _parseVersion(currentVersion);

  static Version _parseVersion(String value) {
    var parsed = Version.parse(value.trim().replaceFirst(RegExp(r'^[vV]'), ''));
    // 应用构建号不影响发布版本先后，预发布标识仍参与比较。
    return Version(
      parsed.major,
      parsed.minor,
      parsed.patch,
      pre: parsed.isPreRelease ? parsed.preRelease.join('.') : null,
    );
  }
}
