// Dart imports:
import 'dart:convert';
import 'dart:io';

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
  var statusCode = exception.response?.statusCode;
  var responseMessage = _readJsonErrorMessage(responseData);
  var message = responseMessage;
  var networkFailure = _isNetworkFailure(exception);
  if (message == null && networkFailure) {
    message = '网络连接失败，请稍后重试';
  }
  message ??= _readHtmlTitle(responseData);
  message ??= exception.error?.toString();
  message ??= exception.message;
  message ??= fallbackMessage;

  // 5xx 多为上游 / 反向代理故障（如 nginx 的 502 错误页），
  // 换成中文提示，上游原始内容只留在日志里。
  var statusMessage = _bangumiStatusMessage(statusCode);
  if (statusMessage != null && responseMessage == null) {
    message = statusMessage;
  }

  var uri = exception.requestOptions.uri;
  try {
    BTLogTool.error(
      '$fallbackMessage [$uri]: ${_logMessage(message, responseData)}',
    );
  } catch (_) {
    // Error handling must not fail when logging is not initialized yet.
  }
  // Keep transport failures separate from real HTTP 5xx responses. The UI
  // uses 666 as the application's network-error code; mapping these failures
  // to 503 incorrectly reports proxy, DNS, TLS, and timeout errors as server
  // failures.
  statusCode ??= 666;
  return BTResponse.error(code: statusCode, message: message, data: null);
}

BTResponse<T> handleBangumiUnexpectedResponse<T>(
  Response response, {
  required String fallbackMessage,
}) {
  var responseMessage = _readJsonErrorMessage(response.data);
  var statusCode = response.statusCode ?? 502;
  if (statusCode >= 200 && statusCode < 300) {
    // mirrox 类镜像会把上游故障包成 2xx + HTML 错误页，
    // 真实状态码只能从错误页标题里取。
    statusCode = _readHtmlStatus(response.data) ?? 502;
  }
  var message = responseMessage;
  message ??= _readHtmlTitle(response.data);
  message ??= '$fallbackMessage: Unexpected response format';

  var statusMessage = _bangumiStatusMessage(statusCode);
  if (statusMessage != null && responseMessage == null) {
    message = statusMessage;
  }

  try {
    BTLogTool.error(
      '$fallbackMessage [${response.realUri}]: '
      '${_logMessage(message, response.data)}',
    );
  } catch (_) {
    // Error handling must not fail when logging is not initialized yet.
  }
  return BTResponse.error(code: statusCode, message: message, data: null);
}

/// 写操作（POST / PATCH / PUT）成功时通常返回空响应体，
/// 但镜像可能把上游故障包成 2xx + HTML 错误页，因此写请求必须校验响应体，
/// 否则会把失败当成成功写回本地状态。
///
/// 返回 null 表示响应正常；否则返回可直接上抛的错误响应。
BTResponse<T>? readBangumiWriteFailure<T>(
  Response response, {
  required String fallbackMessage,
}) {
  var data = response.data;
  if (data == null) return null;
  var map = bangumiJsonMap(data);
  if (map != null) {
    // 正常的回写对象：只要不含错误字段就当作成功。
    if (_readWriteErrorMessage(map) == null) return null;
  } else if (data is List) {
    return null;
  } else if (data is String && data.trim().isEmpty) {
    return null;
  }
  return handleBangumiUnexpectedResponse(
    response,
    fallbackMessage: fallbackMessage,
  );
}

/// 上游错误的中文提示，返回 null 表示保留原始信息。
String? _bangumiStatusMessage(int? statusCode) {
  if (statusCode == null) return null;
  if (statusCode == 405) {
    return '当前 Bangumi 线路不支持该操作，请在设置中切换线路后重试';
  }
  if (statusCode >= 500) {
    return 'Bangumi 服务器暂时不可用（$statusCode），请稍后重试';
  }
  return null;
}

/// 日志里保留上游返回的原始信息（如 nginx 的 502 页面标题）便于排查。
String _logMessage(String message, dynamic responseData) {
  var detail = _readHtmlTitle(responseData);
  if (detail == null || detail == message) return message;
  return '$message ($detail)';
}

/// Bangumi OAuth 常以 HTTP 200 返回 `{"error":"app_nonexistence",...}`。
BTResponse<T>? readBangumiOauthError<T>(
  Map<String, dynamic> data, {
  required String fallbackMessage,
}) {
  var accessToken = data['access_token'];
  if (accessToken is String && accessToken.isNotEmpty) return null;
  var message = _readErrorMessage(data);
  if (message == null) return null;
  try {
    BTLogTool.error('$fallbackMessage: $message');
  } catch (_) {
    // Error handling must not fail when logging is not initialized yet.
  }
  return BTResponse.error(code: 400, message: message, data: null);
}

bool _isNetworkFailure(DioException exception) {
  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return true;
    default:
      break;
  }
  var error = exception.error;
  if (error is SocketException || error is HandshakeException) return true;
  var text = '${error ?? ''} ${exception.message ?? ''}';
  return text.contains('HandshakeException') ||
      text.contains('SocketException') ||
      text.contains('Failed host lookup');
}

String? _readErrorMessage(dynamic data) {
  if (data is String) {
    var decoded = bangumiJsonMap(data);
    if (decoded != null) return _readErrorMessage(decoded);
    return _readHtmlTitle(data);
  }
  if (data is! Map) return null;

  for (var key in ['description', 'title', 'error_description', 'error']) {
    var value = data[key];
    if (value != null && value.toString().isNotEmpty) return value.toString();
  }
  return null;
}

/// 只认 JSON 载荷里的语义化错误。HTML / 纯文本错误页返回 null，
/// 便于区分“服务端给出了明确原因”与“反代返回了错误页”。
String? _readJsonErrorMessage(dynamic data) {
  if (data is String) {
    var decoded = bangumiJsonMap(data);
    return decoded == null ? null : _readErrorMessage(decoded);
  }
  if (data is! Map) return null;
  return _readErrorMessage(data);
}

/// 写操作回包里的错误字段。Bangumi 的错误体为 `title` + `description`，
/// 只命中其一不足以判定失败，避免把正常的回写对象误判成错误。
String? _readWriteErrorMessage(Map data) {
  for (var key in ['error', 'error_description']) {
    var value = data[key];
    if (value != null && value.toString().isNotEmpty) return value.toString();
  }
  var title = data['title'];
  var description = data['description'];
  if (title == null || description == null) return null;
  var text = description.toString();
  return text.isEmpty ? title.toString() : text;
}

String? _readHtmlTitle(dynamic data) {
  if (data is! String) return null;
  var match = RegExp(
    r'<title>([^<]+)</title>',
    caseSensitive: false,
  ).firstMatch(data);
  var title = match?.group(1)?.trim();
  if (title == null || title.isEmpty) return null;
  return title;
}

/// 从错误页标题里取回被镜像包装掉的状态码，如 `502 Bad Gateway · mirrox`。
int? _readHtmlStatus(dynamic data) {
  var title = _readHtmlTitle(data);
  if (title == null) return null;
  var match = RegExp(r'\b([1-5]\d{2})\b').firstMatch(title);
  var status = match == null ? null : int.tryParse(match.group(1)!);
  if (status == null || status < 400) return null;
  return status;
}

/// 把 OAuth / API 响应当成 JSON 对象；HTML 或纯文本返回 null。
Map<String, dynamic>? bangumiJsonMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  if (data is! String) return null;
  var trimmed = data.trim();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
  try {
    var decoded = jsonDecode(trimmed);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }
  return null;
}
