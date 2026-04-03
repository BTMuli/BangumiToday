import 'package:fluent_ui/fluent_ui.dart';

import '../../models/app/response.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';

enum AppErrorType {
  networkError,
  authError,
  notFound,
  serverError,
  rateLimit,
  validationError,
  unknown,
}

class AppError {
  final AppErrorType type;
  final int code;
  final String message;
  final String? userMessage;
  final dynamic data;

  AppError({
    required this.type,
    required this.code,
    required this.message,
    this.userMessage,
    this.data,
  });

  factory AppError.fromResponse(BTResponse response) {
    AppErrorType type;
    String userMessage;

    switch (response.code) {
      case 401:
        type = AppErrorType.authError;
        userMessage = '授权已过期，请重新登录';
        break;
      case 403:
        type = AppErrorType.authError;
        userMessage = '没有权限访问此内容';
        break;
      case 404:
        type = AppErrorType.notFound;
        userMessage = '请求的内容不存在';
        break;
      case 429:
        type = AppErrorType.rateLimit;
        userMessage = '请求过于频繁，请稍后再试';
        break;
      case >= 500:
        type = AppErrorType.serverError;
        userMessage = '服务器错误，请稍后再试';
        break;
      case 666:
        type = AppErrorType.networkError;
        userMessage = '网络连接失败，请检查网络';
        break;
      default:
        type = AppErrorType.unknown;
        userMessage = '操作失败: ${response.message}';
    }

    return AppError(
      type: type,
      code: response.code,
      message: response.message,
      userMessage: userMessage,
      data: response.data,
    );
  }

  String get displayMessage => userMessage ?? message;
}

class BTErrorHandler {
  BTErrorHandler._();

  static Future<void> handle(
    BuildContext context,
    BTResponse response, {
    String? title,
    bool showDialog = false,
    VoidCallback? onRetry,
    VoidCallback? onLogin,
  }) async {
    var error = AppError.fromResponse(response);

    if (showDialog) {
      await _showErrorDialog(
        context,
        error,
        title: title,
        onRetry: onRetry,
        onLogin: onLogin,
      );
    } else {
      await _showErrorInfoBar(context, error, onRetry: onRetry);
    }
  }

  static Future<void> _showErrorInfoBar(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;

    await BtInfobar.error(context, error.displayMessage);
  }

  static Future<void> _showErrorDialog(
    BuildContext context,
    AppError error, {
    String? title,
    VoidCallback? onRetry,
    VoidCallback? onLogin,
  }) async {
    if (!context.mounted) return;

    var actions = <Widget>[];

    if (error.type == AppErrorType.authError && onLogin != null) {
      actions.add(
        Button(
          onPressed: () {
            Navigator.of(context).pop();
            onLogin();
          },
          child: const Text('重新登录'),
        ),
      );
    }

    if (onRetry != null) {
      actions.add(
        Button(
          onPressed: () {
            Navigator.of(context).pop();
            onRetry();
          },
          child: const Text('重试'),
        ),
      );
    }

    actions.add(
      Button(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('关闭'),
      ),
    );

    await showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(title ?? '操作失败'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error.displayMessage),
            SizedBox(height: 8),
            Text(
              '错误代码: ${error.code}',
              style: TextStyle(color: Colors.grey[100], fontSize: 12),
            ),
          ],
        ),
        actions: actions,
      ),
    );
  }

  static Future<void> handleAuthError(
    BuildContext context, {
    VoidCallback? onLogin,
  }) async {
    if (!context.mounted) return;

    var confirm = await showConfirm(
      context,
      title: '授权已过期',
      content: '您的登录状态已过期，是否重新登录？',
    );

    if (confirm && onLogin != null) {
      onLogin();
    }
  }

  static Future<void> handleNetworkError(
    BuildContext context, {
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;

    await BtInfobar.error(context, '网络连接失败，请检查网络设置后重试');
  }
}
