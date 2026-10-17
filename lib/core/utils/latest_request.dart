// Package imports:
import 'package:dio/dio.dart';

/// Shares identical searches; a different search immediately cancels its work.
class LatestRequest<T> {
  Object? _key;
  CancelToken? _token;
  Future<T>? _flight;

  Future<T> run(Object key, Future<T> Function(CancelToken) action) {
    if (_key == key && _flight != null) return _flight!;
    cancel();
    var token = _token = CancelToken();
    _key = key;
    late Future<T> flight;
    flight = Future<T>.sync(() => action(token)).whenComplete(() {
      if (identical(_flight, flight)) _clear();
    });
    return _flight = flight;
  }

  void _clear() {
    _key = null;
    _token = null;
    _flight = null;
  }

  void cancel() {
    _token?.cancel('已切换 RSS 请求');
    _clear();
  }
}
