// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../core/utils/tool_func.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';

/// 吐槽与评论共用的作者信息，仅头像触发用户主页跳转。
class DetailCommentAuthor extends StatelessWidget {
  const DetailCommentAuthor({
    super.key,
    required this.user,
    this.avatarSize = 36,
  });

  final BangumiCommentUser? user;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    var author = user;
    var name = author == null
        ? '未知用户'
        : replaceEscape(
            author.nickname.isEmpty ? author.username : author.nickname,
          );
    return Row(
      children: [
        _buildAvatar(context, name),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                textAlign: TextAlign.start,
                style: BTTypography.bodyStrong(context).copyWith(height: 1.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (author != null) ...[
                const SizedBox(height: 2),
                Text(
                  '@${author.username}',
                  textAlign: TextAlign.start,
                  style: BTTypography.caption(context).copyWith(height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context, String name) {
    var placeholder = SizedBox.square(
      dimension: avatarSize,
      child: Icon(FluentIcons.contact, size: avatarSize * 0.6),
    );
    var author = user;
    if (author == null) return placeholder;
    var label = '在浏览器中查看 $name 的主页';
    var profile =
        '${BtrBangumiApi.siteBaseUrl}/user/'
        '${Uri.encodeComponent(author.username)}';
    return SizedBox.square(
      dimension: avatarSize,
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          link: true,
          child: HyperlinkButton(
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(EdgeInsets.zero),
              backgroundColor: WidgetStatePropertyAll(Colors.transparent),
            ),
            onPressed: () => unawaited(launchUrlString(profile)),
            child: BtBangumiCover(
              imageUrl: author.avatar.medium,
              width: avatarSize,
              height: avatarSize,
              maxRequestEdge: BangumiCoverUrl.thumbMaxEdge,
              borderRadius: BTRadius.mediumBR,
              progressSize: avatarSize * 0.4,
              errorBuilder: (context, {err}) => placeholder,
            ),
          ),
        ),
      ),
    );
  }
}
