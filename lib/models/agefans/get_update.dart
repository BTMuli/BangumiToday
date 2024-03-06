import 'package:json_annotation/json_annotation.dart';

import 'age_base.dart';

part 'get_update.g.dart';

/// 获取一周更新
/// 参考：https://github.com/ihan123/AGE/blob/master/app/src/main/kotlin/cn/xihan/age/util/Api.kt
@JsonSerializable()
class UpdateResponse {
  /// 更新数据
  @JsonKey(name: 'videos')
  List<BaseBangumi> videos;

  /// 总数
  @JsonKey(name: 'total')
  int total;

  /// constructor
  UpdateResponse({
    required this.videos,
    required this.total,
  });

  /// from json
  factory UpdateResponse.fromJson(Map<String, dynamic> json) =>
      _$UpdateResponseFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$UpdateResponseToJson(this);
}
