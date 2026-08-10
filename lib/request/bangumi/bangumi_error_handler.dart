// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../../models/app/response.dart';
import '../../tools/log_tool.dart';

BTResponse<T> handleBangumiDioException<T>(
  DioException exception, {
  required String fallbackMessage,
}) {
  if (exception.type == DioExceptionType.cancel) {
    return BTResponse.error(
      code: 499,
      message: 'Request cancelled',
      data: null,
    );
  }

  var responseData = exception.response?.data;
  var message = _readErrorMessage(responseData);
  message ??= exception.error?.toString();
  message ??= exception.message;
  message ??= fallbackMessage;

  var uri = exception.requestOptions.uri;
  try {
    BTLogTool.error('$fallbackMessage [$uri]: $message');
  } catch (_) {
    // Error handling must not fail when logging is not initialized yet.
  }
  return BTResponse.error(
    code: exception.response?.statusCode ?? 666,
    message: message,
    data: null,
  );
}

BTResponse<T> handleBangumiUnexpectedResponse<T>(
  Response response, {
  required String fallbackMessage,
}) {
  var message = _readErrorMessage(response.data);
  message ??= '$fallbackMessage: Unexpected response format';
  var statusCode = response.statusCode ?? 502;
  if (statusCode >= 200 && statusCode < 300) statusCode = 502;

  try {
    BTLogTool.error('$fallbackMessage [${response.realUri}]: $message');
  } catch (_) {
    // Error handling must not fail when logging is not initialized yet.
  }
  return BTResponse.error(code: statusCode, message: message, data: null);
}

String? _readErrorMessage(dynamic data) {
  if (data is! Map) return null;

  for (var key in ['description', 'title', 'error_description', 'error']) {
    var value = data[key];
    if (value != null && value.toString().isNotEmpty) return value.toString();
  }
  return null;
}
