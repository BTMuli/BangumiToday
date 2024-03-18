import '../../models/app/err.dart';
import '../../models/bangumi/get_calendar.dart';
import '../../models/bangumi/get_subject.dart';
import '../core/client.dart';

/// bangumi.tv 的 API
/// 详细文档请参考 https://bangumi.github.io/api/
class BangumiAPI {
  /// 请求客户端
  late final BTRequestClient client;

  /// 基础 URL
  final String baseUrl = 'https://api.bgm.tv';

  /// 构造函数
  BangumiAPI() {
    client = BTRequestClient();
    client.dio.options.baseUrl = baseUrl;
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
    if(response.statusCode == 200) {
      return Subject.fromJson(response.data as Map<String, dynamic>);
    } else {
      throw BTError.requestError(msg: 'Failed to load detail');
    }
  }
}
