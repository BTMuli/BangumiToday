import 'dart:convert';

import 'package:dio/dio.dart';

import '../../models/app/response.dart';
import '../../tools/log_tool.dart';

typedef ResponseParser<T> = T Function(dynamic data);

class BTApiHandler {
  BTApiHandler._();

  static final BTApiHandler instance = BTApiHandler._();

  factory BTApiHandler() => instance;

  Future<BTResponse<T>> handleRequest<T>({
    required Future<Response> Function() request,
    required ResponseParser<T> parser,
    String? logContext,
  }) async {
    try {
      var response = await request();
      var data = parser(response.data);
      return BTResponse.success(data: data);
    } on DioException catch (e) {
      return _handleDioError<T>(e, logContext);
    } catch (e) {
      return _handleGenericError<T>(e, logContext);
    }
  }

  Future<BTResponse<T>> handleListRequest<T>({
    required Future<Response> Function() request,
    required T Function(List<dynamic>) parser,
    String? logContext,
  }) async {
    try {
      var response = await request();
      var data = parser(response.data as List);
      return BTResponse.success(data: data);
    } on DioException catch (e) {
      return _handleDioError<T>(e, logContext);
    } catch (e) {
      return _handleGenericError<T>(e, logContext);
    }
  }

  Future<BTResponse<T>> handleVoidRequest<T>({
    required Future<Response> Function() request,
    String? logContext,
  }) async {
    try {
      await request();
      return BTResponse.success(data: null as T);
    } on DioException catch (e) {
      return _handleDioError<T>(e, logContext);
    } catch (e) {
      return _handleGenericError<T>(e, logContext);
    }
  }

  BTResponse<T> _handleDioError<T>(DioException e, String? logContext) {
    var context = logContext ?? 'API request';
    var statusCode = e.response?.statusCode ?? 666;
    var errorData = e.response?.data;

    String errorMessage;
    dynamic errorDetail;

    if (errorData != null && errorData is Map<String, dynamic>) {
      if (errorData.containsKey('title')) {
        errorMessage = errorData['title'] ?? 'Request failed';
        errorDetail = errorData;
      } else if (errorData.containsKey('error')) {
        errorMessage = errorData['error'] ?? 'Request failed';
        errorDetail = errorData;
      } else {
        errorMessage = e.message ?? 'Request failed';
        errorDetail = errorData;
      }
    } else {
      errorMessage = e.message ?? 'Request failed';
      errorDetail = e.error?.toString();
    }

    BTLogTool.error('$context failed: ${jsonEncode(errorDetail)}');
    return BTResponse<T>(
      code: statusCode,
      message: errorMessage,
      data: errorDetail,
    );
  }

  BTResponse<T> _handleGenericError<T>(Object e, String? logContext) {
    var context = logContext ?? 'API request';
    BTLogTool.error('$context failed: $e');
    return BTResponse<T>(
      code: 666,
      message: e.toString(),
      data: null,
    );
  }
}
