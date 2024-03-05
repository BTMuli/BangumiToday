import '../../models/bangumi/get_calendar.dart';
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

  /// 每日放松
  Future<List<CalendarItem>> getToday() async {
    var response = await client.dio.get('/calendar');
    // 如果请求成功
    if (response.statusCode == 200) {
      return (response.data as List)
          .map((e) => CalendarItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      // todo 错误处理
      throw Exception('Failed to load today');
    }
  }
}
