import 'package:fluent_ui/fluent_ui.dart';

import '../../models/app/err.dart';
import '../../models/bangumi/get_calendar.dart';
import '../../models/bangumi/get_subject.dart';
import '../../models/bangumi/oauth.dart';
import '../../tools/config_tool.dart';
import '../core/client.dart';

/// bangumi.tv 的 API
/// 详细文档请参考 https://bangumi.github.io/api/
class BangumiAPI {
  /// 请求客户端
  late final BTRequestClient client;

  /// 基础 URL
  final String baseUrl = 'https://api.bgm.tv';

  /// access token
  static late String accessToken = '';

  /// 构造函数
  BangumiAPI() {
    client = BTRequestClient();
    client.dio.options.baseUrl = baseUrl;
  }

  /// 尝试获取访问令牌
  Future<void> refreshGetAccessToken({String? token}) async {
    if (token != null) {
      accessToken = token;
      return;
    }
    var bgmOauth = BTConfigTool.readConfig(key: 'bgm_oauth');
    if (bgmOauth != null) {
      try {
        var data = BangumiOauthConfig.fromJson(bgmOauth);
        if (data.accessToken != "") {
          accessToken = data.accessToken;
          return;
        }
      } on Exception catch (e) {
        debugPrint(e.toString());
      }
    }
  }

  /// 每日放送
  Future<List<CalendarItem>> getToday() async {
    var response = await client.dio.get('/calendar');
    if (response.statusCode == 200) {
      return (response.data as List)
          .map((e) => CalendarItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw BTError.requestError(msg: 'Failed to load today');
    }
  }

  /// 获取番剧详情
  Future<Subject> getDetail(String id) async {
    var response = await client.dio.get('/v0/subjects/$id');
    if (response.statusCode == 200) {
      return Subject.fromJson(response.data as Map<String, dynamic>);
    } else {
      throw BTError.requestError(msg: 'Failed to load detail');
    }
  }
}
