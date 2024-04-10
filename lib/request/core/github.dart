import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';

import '../../models/app/err.dart';
import 'client.dart';

/// 调用 github api
class GithubAPI {
  /// 请求客户端
  final BTRequestClient client;

  /// 构造函数
  GithubAPI() : client = BTRequestClient();

  /// 获取最新Release版本
  Future<String> getLatestRelease(String user, String repo) async {
    var response = await client.dio
        .get('https://api.github.com/repos/$user/$repo/releases/latest');
    if (response.statusCode != 200) {
      throw BTError.requestError(msg: 'Failed to load latest release');
    }
    debugPrint(jsonEncode(response.data));
    return response.data['tag_name'] as String;
  }
}
