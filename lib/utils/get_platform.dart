import 'package:flutter/foundation.dart';

/// 判断是移动端还是PC端
Future<bool> isMobile() async {
  var platform = defaultTargetPlatform;
  if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
    return true;
  }
  return false;
}
