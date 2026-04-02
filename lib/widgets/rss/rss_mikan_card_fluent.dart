import 'dart:ui';

import 'package:dart_rss/dart_rss.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jiffy/jiffy.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../database/app/app_config.dart';
import '../../tools/download_tool.dart';
import '../../ui/bt_infobar.dart';
import '../../utils/tool_func.dart';

class RssMikanCardFluent extends StatefulWidget {
  final RssItem item;
  final String? dir;

  const RssMikanCardFluent({super.key, required this.item, this.dir});

  @override
  State<RssMikanCardFluent> createState() => _RssMikanCardFluentState();
}

class _RssMikanCardFluentState extends State<RssMikanCardFluent> {
  bool _isHovered = false;
  bool _isPressed = false;
  final BtsAppConfig sqliteConfig = BtsAppConfig();

  RssItem get item => widget.item;

  Future<void> _download(BuildContext context) async {
    if (item.enclosure?.url == null || item.title == null) return;

    var mikanUrl = await sqliteConfig.readMikanUrl();
    var urlReal = item.enclosure!.url!;
    if (mikanUrl != null && mikanUrl.isNotEmpty) {
      var url = Uri.parse(item.enclosure!.url!);
      var urlDomain = '${url.scheme}://${url.host}';
      urlReal = item.enclosure!.url!.replaceFirst(urlDomain, mikanUrl);
    }

    String? saveDir = widget.dir;
    if (saveDir == null || saveDir.isEmpty) {
      saveDir = await getDirectoryPath();
    }

    if (saveDir == null || saveDir.isEmpty) {
      if (context.mounted) await BtInfobar.error(context, '未选择下载目录');
      return;
    }

    if (context.mounted) {
      var savePath = await BTDownloadTool().downloadRssTorrent(
        urlReal,
        item.title!,
        context: context,
      );
      if (savePath.isNotEmpty) {
        await launchUrlString('mo://new-task/?type=torrent&dir=$saveDir');
        await launchUrlString('file://$savePath');
      }
    }
  }

  Future<void> _openLink() async {
    if (item.link == null || item.link!.isEmpty) {
      if (mounted) await BtInfobar.error(context, '链接为空');
      return;
    }

    var mikanUrl = await sqliteConfig.readMikanUrl();
    var linkReal = item.link!;
    if (mikanUrl != null && mikanUrl.isNotEmpty) {
      var url = Uri.parse(item.link!);
      var urlDomain = '${url.scheme}://${url.host}';
      linkReal = item.link!.replaceFirst(urlDomain, mikanUrl);
    }
    await launchUrlString(linkReal);
  }

  @override
  Widget build(BuildContext context) {
    var theme = FluentTheme.of(context);
    var accentColor = theme.accentColor;

    String sizeStr = '';
    if (item.enclosure?.length != null) {
      sizeStr = filesize(item.enclosure!.length);
    }

    String pubDate = '';
    if (item.pubDate != null) {
      pubDate = Jiffy.parse(
        item.pubDate!,
        pattern: 'yyyy-MM-ddTHH:mm:ss',
      ).format(pattern: 'MM-dd HH:mm');
    }

    var backgroundColor = theme.brightness == Brightness.light
        ? Colors.white.withValues(alpha: _isHovered ? 0.95 : 0.85)
        : Colors.grey[190].withValues(alpha: _isHovered ? 0.95 : 0.85);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: theme.brightness == Brightness.light
                  ? Colors.grey[60]
                  : Colors.grey[130],
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.12 : 0.08),
                blurRadius: _isHovered ? 12 : 8,
                spreadRadius: 0,
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _isHovered ? 20 : 10,
                sigmaY: _isHovered ? 20 : 10,
              ),
              child: Transform.translate(
                offset: Offset(0, _isPressed ? 2.0 : 0.0),
                child: Padding(
                  padding: EdgeInsets.all(12.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: item.title ?? '',
                          child: Text(
                            item.title ?? '',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Icon(
                            FluentIcons.clock,
                            size: 12.sp,
                            color: theme.brightness == Brightness.light
                                ? Colors.grey[130]
                                : Colors.grey[100],
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            pubDate,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: theme.brightness == Brightness.light
                                  ? Colors.grey[130]
                                  : Colors.grey[100],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Icon(
                            FluentIcons.download,
                            size: 12.sp,
                            color: theme.brightness == Brightness.light
                                ? Colors.grey[130]
                                : Colors.grey[100],
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            sizeStr,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: theme.brightness == Brightness.light
                                  ? Colors.grey[130]
                                  : Colors.grey[100],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Tooltip(
                            message: '下载',
                            child: IconButton(
                              icon: Icon(
                                FluentIcons.download,
                                size: 16.sp,
                                color: accentColor,
                              ),
                              onPressed: () => _download(context),
                            ),
                          ),
                          Tooltip(
                            message: '打开链接',
                            child: IconButton(
                              icon: Icon(
                                FluentIcons.edge_logo,
                                size: 16.sp,
                                color: accentColor,
                              ),
                              onPressed: _openLink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
