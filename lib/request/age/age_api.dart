// Project imports:
import '../../models/age/get_detail.dart';
import '../../models/age/get_home_list.dart';
import '../../models/age/get_update.dart';
import '../../models/app/err.dart';
import '../core/client.dart';

/// 常量
const agePicUrl = 'https://cdn.aqdstatic.com:966/age/{aid}.jpg';

/// age 的 api
/// 参考：https://github.com/xihan123/AGE/blob/master/app/src/main/kotlin/cn/xihan/age/util/Api.kt
class AgeAPI {
  /// 请求客户端
  late final BTRequestClient client;

  /// 基础 URL
  final String baseUrl = 'https://api.agedm.org/v2';

  /// 构造函数
  AgeAPI() {
    client = BTRequestClient();
    client.dio.options.baseUrl = baseUrl;
  }

  /// 首页模型
  Future<HomeListResponse> getHomeList() async {
    var response = await client.dio.get('/home-list');
    if (response.statusCode == 200) {
      return HomeListResponse.fromJson(response.data);
    } else {
      throw BTError.requestError(msg: 'agefans getHomeList error');
    }
  }

  /// 一周更新
  /// 需要 page 跟 size 参数
  Future<UpdateResponse> getUpdate(int page, int size) async {
    var response = await client.dio.get('/update', queryParameters: {
      'page': page,
      'size': size,
    });
    if (response.statusCode == 200) {
      return UpdateResponse.fromJson(response.data);
    } else {
      throw BTError.requestError(msg: 'agefans getUpdate error');
    }
  }

  /// 番剧详情
  /// 需要 aid 参数
  Future<DetailResponse> getDetail(int aid) async {
    var response = await client.dio.get('/detail/$aid');
    if (response.statusCode == 200) {
      return DetailResponse.fromJson(response.data);
    } else {
      throw BTError.requestError(msg: 'agefans getDetail error');
    }
  }
}
