// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../models/app/response.dart';

class AppRespErrWidget extends StatelessWidget {
  /// 错误信息
  final BTResponse response;

  /// 构造函数
  const AppRespErrWidget(this.response, {super.key});

  /// 构建标题
  Widget buildTitle(String prefix, String data) {
    return Text(
      '$prefix: $data',
      style: TextStyle(fontSize: 20),
      textAlign: TextAlign.left,
    );
  }

  /// 构建内容
  List<Widget> buildContent() {
    var content = <Widget>[
      buildTitle('code', response.code.toString()),
      SizedBox(height: 12.h),
      buildTitle('message', response.message),
      SizedBox(height: 12.h),
    ];
    if (response.code != 0 || response.data == null) {
      return content;
    }
    String text;
    try {
      text = const JsonEncoder.withIndent('  ').convert(response.data);
    } catch (e) {
      text = response.data.toString();
    }
    return [
      ...content,
      Container(
        height: 200.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withAlpha(20),
        ),
        child: SingleChildScrollView(
          child: Text(text, style: TextStyle(fontSize: 20)),
        ),
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: buildContent(),
    );
  }
}
