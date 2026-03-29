import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi_today/core/errors/error_handler.dart';
import 'package:bangumi_today/models/app/response.dart';

void main() {
  group('AppError', () {
    test('fromResponse returns correct error type for 401', () {
      var response = BTResponse.error(
        code: 401,
        message: 'Unauthorized',
        data: null,
      );
      var error = AppError.fromResponse(response);
      expect(error.type, AppErrorType.authError);
      expect(error.code, 401);
    });

    test('fromResponse returns correct error type for 403', () {
      var response = BTResponse.error(
        code: 403,
        message: 'Forbidden',
        data: null,
      );
      var error = AppError.fromResponse(response);
      expect(error.type, AppErrorType.authError);
    });

    test('fromResponse returns correct error type for 404', () {
      var response = BTResponse.error(
        code: 404,
        message: 'Not Found',
        data: null,
      );
      var error = AppError.fromResponse(response);
      expect(error.type, AppErrorType.notFound);
    });

    test('fromResponse returns correct error type for 429', () {
      var response = BTResponse.error(
        code: 429,
        message: 'Too Many Requests',
        data: null,
      );
      var error = AppError.fromResponse(response);
      expect(error.type, AppErrorType.rateLimit);
    });

    test('fromResponse returns correct error type for 500', () {
      var response = BTResponse.error(
        code: 500,
        message: 'Server Error',
        data: null,
      );
      var error = AppError.fromResponse(response);
      expect(error.type, AppErrorType.serverError);
    });

    test('fromResponse returns correct error type for 666 (network)', () {
      var response = BTResponse.error(
        code: 666,
        message: 'Network Error',
        data: null,
      );
      var error = AppError.fromResponse(response);
      expect(error.type, AppErrorType.serverError);
    });

    test('displayMessage returns userMessage when available', () {
      var error = AppError(
        type: AppErrorType.authError,
        code: 401,
        message: 'Unauthorized',
        userMessage: '授权已过期',
      );
      expect(error.displayMessage, '授权已过期');
    });

    test('displayMessage returns message when userMessage is null', () {
      var error = AppError(
        type: AppErrorType.unknown,
        code: 999,
        message: 'Unknown error',
      );
      expect(error.displayMessage, 'Unknown error');
    });
  });
}
