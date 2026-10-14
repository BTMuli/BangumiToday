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
  var message = responseMessage ?? _networkFailureMessage(exception);
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
    BTLogTool.error([
      '$fallbackMessage [${exception.requestOptions.method} $uri]: '
          '${_logMessage(message, responseData)}',
      'type=${exception.type.name}, status=${statusCode ?? 'none'}',
      if (exception.error != null) 'cause=${exception.error}',
      if (exception.message != null) 'detail=${exception.message}',
    ]);
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
  if (statusCode == 429) {
    return '请求过于频繁，已被 Bangumi 限流（429），请稍后再试';
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

String? _networkFailureMessage(DioException exception) {
  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
      return '连接 Bangumi 超时，请检查网络或代理设置后重试';
    case DioExceptionType.sendTimeout:
      return '发送 Bangumi 请求超时，请检查网络或代理设置后重试';
    case DioExceptionType.receiveTimeout:
      return '等待 Bangumi 响应超时，请稍后重试或切换 Bangumi 线路';
    case DioExceptionType.badCertificate:
      return 'Bangumi 的 HTTPS 证书校验失败，请检查系统时间或代理设置';
    default:
      break;
  }
  var error = exception.error;
  var text = '${error ?? ''} ${exception.message ?? ''}'.toLowerCase();
  if (text.contains('failed host lookup') ||
      text.contains('no such host is known')) {
    return '访问 Bangumi 时域名解析失败，请检查 DNS 或代理设置';
  }
  if (error is TlsException ||
      text.contains('handshakeexception') ||
      text.contains('tlsexception')) {
    return '与 Bangumi 建立 HTTPS 安全连接失败，请检查代理设置或切换 Bangumi 线路';
  }
  if (text.contains('connection refused') ||
      text.contains('actively refused')) {
    return '连接 Bangumi 被拒绝，请检查代理设置或切换 Bangumi 线路';
  }
  if (text.contains('connection reset') ||
      text.contains('connection closed') ||
      text.contains('connection aborted')) {
    return '与 Bangumi 的连接意外中断，请稍后重试或检查代理设置';
  }
  if (exception.type == DioExceptionType.connectionError ||
      error is SocketException ||
      text.contains('socketexception')) {
    return '无法连接 Bangumi，请检查网络或代理设置，或切换 Bangumi 线路';
  }
  return null;
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
