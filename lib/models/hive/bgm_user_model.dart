// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:hive/hive.dart';

// Project imports:
import '../bangumi/bangumi_model.dart';

/// Bangumi 用户
class BgmUserHiveModel {
  /// 用户
  final BangumiUser? user;

  /// accessToken
  final String? accessToken;

  /// refreshToken
  final String? refreshToken;

  /// expireTime
  final DateTime? expireTime;

  /// 初始化用户
  BgmUserHiveModel({
    this.user,
    this.accessToken,
    this.refreshToken,
    this.expireTime,
  });
}

/// Bangumi 用户的适配器
class BgmUserHiveAdapter extends TypeAdapter<BgmUserHiveModel> {
  @override
  final int typeId = 2;

  @override
  BgmUserHiveModel read(BinaryReader reader) {
    var userReader = reader.read();
    BangumiUser? user;
    if (userReader == 'null') {
      user = null;
    } else {
      user = BangumiUser.fromJson(jsonDecode(userReader as String));
    }
    var accessToken = reader.read() as String?;
    var refreshToken = reader.read() as String?;
    var expireTime = reader.read() as DateTime?;
    return BgmUserHiveModel(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expireTime: expireTime,
    );
  }

  @override
  void write(BinaryWriter writer, BgmUserHiveModel obj) {
    writer.write(jsonEncode(obj.user));
    writer.write(obj.accessToken);
    writer.write(obj.refreshToken);
    writer.write(obj.expireTime);
  }
}
