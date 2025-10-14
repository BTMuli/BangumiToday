// Project imports:
import '../../tools/log_tool.dart';

/// 自定义错误类型枚举
enum BTErrorType {
  /// 未知错误
  unknownError,

  /// 数据源错误
  sourceError,

  /// 数据错误
  dataError,

  /// 请求错误
  requestError,

  /// 未实现错误
  unimplementedError,
}

/// 自定义错误类型-数据源错误
class BTError implements Exception {
  /// 错误类型
  BTErrorType type;

  /// 错误信息
  String message;

  /// 构造函数
  BTError({this.type = BTErrorType.unknownError, this.message = '未知错误'}) {
    BTLogTool.error(toString());
  }

  /// 构造函数-从异常
  static BTError fromException(Exception e) {
    return BTError.unknownError(msg: e.toString());
  }

  /// 构造函数-未知错误
  static BTError unknownError({String msg = 'unknown error'}) {
    return BTError(type: BTErrorType.unknownError, message: msg);
  }

  /// 构造函数-资源错误
  static BTError sourceError({String msg = 'source is not bangumi'}) {
    return BTError(type: BTErrorType.sourceError, message: msg);
  }

  /// 构造函数-数据错误
  static BTError dataError({String msg = 'data is null'}) {
    return BTError(type: BTErrorType.dataError, message: msg);
  }

  /// 构造函数-未实现错误
  static BTError unimplementedError({String msg = 'unimplemented'}) {
    return BTError(type: BTErrorType.unimplementedError, message: msg);
  }

  /// 构造函数-请求错误
  static BTError requestError({String msg = 'request error'}) {
    return BTError(type: BTErrorType.requestError, message: msg);
  }

  @override
  String toString() {
    return 'BTError: type=$type, message=$message';
  }
}
