// Dart imports:
import 'dart:ui';

// Package imports:
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiffy/jiffy.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../models/rss/rss.dart';
import '../../store/bt_download_store.dart';
import '../../tools/download_tool.dart';
import '../../ui/bt_infobar.dart';
import '../../utils/tool_func.dart';

class RssComicatCardFluent extends ConsumerStatefulWidget {
  final RssItem item;

  const RssComicatCardFluent({super.key, required this.item});

  @override
  ConsumerState<RssComicatCardFluent> createState() =>
      _RssComicatCardFluentState();
}

class _RssComicatCardFluentState extends ConsumerState<RssComicatCardFluent> {
  bool _isHovered = false;
  bool _isPressed = false;

  RssItem get item => widget.item;

  Future<void> _download(BuildContext context) async {
    if (item.enclosure?.url == null || item.title == null) return;

    var saveDir = await getDirectoryPath();
    if (saveDir == null || saveDir.isEmpty) {
      if (context.mounted) await BtInfobar.error(context, '未选择下载目录');
      return;
    }

    var savePath = await BTDownloadTool().downloadRssTorrent(
      item.enclosure!.url!,
      item.title!,
    );

    if (savePath.isNotEmpty) {
      try {
        await ref
            .read(btDownloadStoreProvider)
            .addTorrentFile(
              torrentPath: savePath,
              savePath: saveDir,
              displayName: item.title,
            );
        if (context.mounted) {
          await BtInfobar.success(context, '下载任务已添加');
        }
      } catch (error) {
        if (context.mounted) {
          await BtInfobar.error(context, error.toString());
        }
      }
    }
  }

  Future<void> _openLink() async {
    if (item.link == null || item.link!.isEmpty) return;
    await launchUrlString(item.link!);
  }

  @override
  Widget build(BuildContext context) {
    var theme = FluentTheme.of(context);
    var accentColor = theme.accentColor;

    String title = '';
    if (item.title != null && item.title!.isNotEmpty) {
      title = replaceEscape(item.title!);
    }

    String time = '';
    if (item.pubDate != null && item.pubDate!.isNotEmpty) {
      time = Jiffy.parse(
        item.pubDate!,
        pattern: 'EEE, dd MMM yyyy HH:mm:ss Z',
      ).format(pattern: 'MM-dd HH:mm');
    }

    // String sizeStr = '';
    // if (item.enclosure?.length != null) {
    //   sizeStr = filesize(item.enclosure!.length);
    // }

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
            borderRadius: BorderRadius.circular(8),
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
            borderRadius: BorderRadius.circular(7),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _isHovered ? 20 : 10,
                sigmaY: _isHovered ? 20 : 10,
              ),
              child: Transform.translate(
                offset: Offset(0, _isPressed ? 2.0 : 0.0),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: title,
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          if (item.categories.isNotEmpty &&
                              item.categories.first.value != null &&
                              item.categories.first.value!.isNotEmpty) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.categories.first.value!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                          ],
                          if (item.author != null &&
                              item.author!.isNotEmpty) ...[
                            Icon(
                              FluentIcons.contact,
                              size: 12,
                              color: theme.brightness == Brightness.light
                                  ? Colors.grey[130]
                                  : Colors.grey[100],
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.author!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.brightness == Brightness.light
                                      ? Colors.grey[130]
                                      : Colors.grey[100],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 12),
                          ],
                          Icon(
                            FluentIcons.clock,
                            size: 12,
                            color: theme.brightness == Brightness.light
                                ? Colors.grey[130]
                                : Colors.grey[100],
                          ),
                          SizedBox(width: 4),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.brightness == Brightness.light
                                  ? Colors.grey[130]
                                  : Colors.grey[100],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          // Icon(
                          //   FluentIcons.download,
                          //   size: 12,
                          //   color: theme.brightness == Brightness.light
                          //       ? Colors.grey[130]
                          //       : Colors.grey[100],
                          // ),
                          // SizedBox(width: 4),
                          // Text(
                          //   sizeStr,
                          //   style: TextStyle(
                          //     fontSize: 11,
                          //     color: theme.brightness == Brightness.light
                          //         ? Colors.grey[130]
                          //         : Colors.grey[100],
                          //   ),
                          // ),
                          if (item.enclosure?.type != null &&
                              item.enclosure!.type!.isNotEmpty) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.enclosure!.type!
                                    .split('/')
                                    .last
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Tooltip(
                            message: '内置下载',
                            child: IconButton(
                              icon: Icon(
                                FluentIcons.download,
                                size: 16,
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
                                size: 16,
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
