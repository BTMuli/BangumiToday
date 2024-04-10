import 'package:json_annotation/json_annotation.dart';

part 'response.g.dart';

/// 通用响应-成功
@JsonSerializable(genericArgumentFactories: true)
class BTResponse<T> {
  /// code
  @JsonKey(name: 'code')
  int code;

  /// message
  @JsonKey(name: 'message')
  String message;

  /// data
  @JsonKey(name: 'data')
  T? data;

  /// constructor
  BTResponse({
    required this.code,
    required this.message,
    required this.data,
  });

  /// error
  static BTResponse<U> error<U>(
          {required int code, required String message, required U? data}) =>
      BTResponse(code: code, message: message, data: data);

  /// success
  static BTResponse<T> success<T>({required T data}) =>
      BTResponse(code: 0, message: 'success', data: data);

  /// from json
  factory BTResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json) fromJsonT,
  ) =>
      _$BTResponseFromJson(json, fromJsonT);

  /// to json
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$BTResponseToJson(this, toJsonT);
}
