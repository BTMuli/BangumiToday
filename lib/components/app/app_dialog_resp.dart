import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/app/response.dart';

/// 构建内容
Widget buildContent(BTResponse resp) {
  var codeWidgets = <Widget>[
    Text(
      'code: ${resp.code}',
      style: TextStyle(fontSize: 20.sp),
      textAlign: TextAlign.left,
    ),
    SizedBox(height: 12.h),
    Text(
      'message: ${resp.message}',
      style: TextStyle(fontSize: 20.sp),
      textAlign: TextAlign.left,
    ),
    SizedBox(height: 12.h),
  ];
  var showWidgets = <Widget>[];
  if (resp.code != 0) {
    showWidgets.addAll(codeWidgets);
  }
  if (resp.data == null) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: codeWidgets,
    );
  }
  String text;
  try {
    text = const JsonEncoder.withIndent('  ').convert(resp.data);

    /// ignore: empty_catches, avoid_catches_without_on_clauses
  } catch (e) {
    text = resp.data.toString();
  }
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      ...showWidgets,
      Container(
        height: 200.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withAlpha(20),
        ),
        child: SingleChildScrollView(
          child: Text(text, style: TextStyle(fontSize: 20.sp)),
        ),
      )
    ],
  );
}

/// 处理响应失败的回调
Future<void> showRespErr(
  BTResponse resp,
  BuildContext context, {
  String? title,
}) async {
  String til;
  if (title != null) {
    til = title;
  } else {
    til = resp.code == 0 ? '请求成功' : '请求失败';
  }
  showDialog(
    barrierDismissible: true,
    context: context,
    builder: (context) {
      return ContentDialog(
        title: Text(til),
        content: buildContent(resp),
        actions: [
          Button(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
}
