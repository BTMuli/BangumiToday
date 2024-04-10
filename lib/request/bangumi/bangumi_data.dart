import '../../models/app/err.dart';
import '../../models/bangumi/data_meta.dart';
import '../core/client.dart';

/// 负责BangumiData的请求
/// Repo: https://github.com/bangumi-data/bangumi-data
/// CDN: https://unpkg.com/bangumi-data@0.3/dist/data.json
class BTBangumiData {
  /// 请求客户端
  late final BTRequestClient client;

  /// 基础 URL
  final String baseUrl = 'https://unpkg.com/bangumi-data@0.3/dist/data.json';

  /// 构造函数
  BTBangumiData() {
    client = BTRequestClient();
    client.dio.options.baseUrl = baseUrl;
  }

  /// 获取番剧数据
  Future<BangumiData> getBangumiData() async {
    var response = await client.dio.get('');
    if (response.statusCode != 200) {
      throw BTError.requestError(msg: 'Failed to load bangumi data');
    }
    return BangumiData.fromJson(response.data as Map<String, dynamic>);
  }
}
