// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_data_model.dart';
import '../../tools/log_tool.dart';
import '../core/client.dart';

/// 负责BangumiData的请求
/// Repo: https://github.com/bangumi-data/bangumi-data
/// CDN: https://unpkg.com/bangumi-data@0.3/dist/data.json
class BtrBangumiDataApi {
  /// 请求客户端
  late final BtrClient client;

  /// 获取数据的基础 URL
  final String jsonUrl = 'https://unpkg.com/bangumi-data@0.3/dist/data.json';

  /// 仓库的基础 URL，用于获取版本信息
  final String repoUrl =
      'https://api.github.com/repos/'
      'bangumi-data/bangumi-data/releases/latest';

  /// 构造函数
  BtrBangumiDataApi() {
    client = BtrClient();
  }

  /// 获取番剧数据
  Future<BTResponse> getData() async {
    try {
      var response = await client.dio.request(
        jsonUrl,
        options: Options(
          headers: {'Accept': 'application/json'},
          method: 'GET',
        ),
      );
      assert(response.data is Map<String, dynamic>);
      return BangumiDataResp.success(
        data: BangumiDataJson.fromJson(response.data),
      );
    } on DioException catch (e) {
      BTLogTool.error('Failed to load bangumi data ${e.response?.data}');
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: 'Failed to load bangumi data',
        data: e.response?.data,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to load bangumi data $e');
      return BTResponse.error(
        code: 666,
        message: 'Failed to load bangumi data',
        data: e.toString(),
      );
    }
  }

  /// 获取番剧数据的版本信息
  Future<BTResponse> getVersion() async {
    try {
      var response = await client.dio.request(
        repoUrl,
        options: Options(
          headers: {'Accept': 'application/json'},
          method: 'GET',
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
      var body = response.data;
      var version = body is Map<String, dynamic> ? body['tag_name'] : null;
      // 发布版不执行 assert，必须在运行时确认响应包含可用的版本号。
      if (version is! String || version.trim().isEmpty) {
        BTLogTool.error('Invalid bangumiData version response: $body');
        return BTResponse.error(
          code: 666,
          message: '获取远程版本失败：响应缺少有效的 tag_name',
          data: body,
        );
      }
      return BTResponse.success(data: version.trim());
    } on DioException catch (e) {
      BTLogTool.error('Failed to load bangumiData version ${e.response?.data}');
      var body = e.response?.data;
      var message = body is Map<String, dynamic> ? body['message'] : null;
      return BTResponse.error(
        code: e.response?.statusCode ?? 666,
        message: message is String && message.trim().isNotEmpty
            ? '获取远程版本失败：$message'
            : '获取远程版本失败',
        data: body,
      );
    } on Exception catch (e) {
      BTLogTool.error('Failed to load bangumiData version $e');
      return BTResponse.error(
        code: 666,
        message: '获取远程版本失败',
        data: e.toString(),
      );
    }
  }
}
