// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../core/constants/app_constants.dart';
import '../models/app/app_release.dart';
import '../models/app/response.dart';
import '../tools/log_tool.dart';
import 'core/client.dart';

/// 手动查询应用的最新正式版本，复用应用代理与请求超时配置。
class BtrAppUpdateApi {
  static Future<BTResponse<AppRelease>> getLatestRelease() async {
    var client = BtrClient();
    try {
      var response = await client.dio.get<dynamic>(
        BTAppConstants.appLatestReleaseApi,
        options: Options(
          headers: {
            'Accept': 'application/vnd.github+json',
            'User-Agent': await getClientUA(),
          },
          validateStatus: (status) => status == 200,
        ),
      );
      var body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const FormatException('发布信息格式无效');
      }
      return BTResponse.success(data: AppRelease.fromJson(body));
    } on DioException catch (error) {
      BTLogTool.warn('检测应用更新失败：$error');
      return BTResponse.error(
        code: error.response?.statusCode ?? 666,
        message: switch (error.response?.statusCode) {
          403 || 429 => '检测更新请求受限，请稍后重试',
          404 => '暂未找到已发布的正式版本',
          _ => '检测更新失败，请检查网络或代理设置后重试',
        },
        data: null,
      );
    } on FormatException catch (error) {
      BTLogTool.warn('应用发布信息无效：$error');
      return BTResponse.error(
        code: 666,
        message: '检测更新失败：发布版本信息无效',
        data: null,
      );
    } finally {
      client.dispose();
    }
  }
}
