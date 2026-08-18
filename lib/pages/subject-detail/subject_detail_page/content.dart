part of '../subject_detail_page.dart';

extension _SubjectDetailContent on _SubjectDetailPageState {
  Widget buildSummary(String summary) {
    if (summary == '') {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              FluentIcons.error_badge,
              size: 16,
              color: BTColors.textTertiary(context),
            ),
            SizedBox(width: 8),
            Text('暂无简介', style: BTTypography.body(context)),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: SelectableText(
        summary,
        style: BTTypography.body(context),
        contextMenuBuilder: buildContextMenu,
      ),
    );
  }

  Widget buildOtherInfo(List<BangumiInfoBoxItem> infobox) {
    if (infobox.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              FluentIcons.info,
              size: 16,
              color: BTColors.textTertiary(context),
            ),
            SizedBox(width: 8),
            Text('暂无其他信息', style: BTTypography.body(context)),
          ],
        ),
      );
    }
    var res = <Widget>[];
    for (var item in infobox) {
      String value;
      if (item.value is List) {
        var list = item.value as List;
        value = list
            .map((e) => e['k'] != null ? '${e['k']}: ${e['v']}' : e['v'])
            .toList()
            .map((e) => replaceEscape(e as String))
            .join('\n');
        res.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.key, style: BTTypography.bodyStrong(context)),
                SizedBox(height: 2),
                SelectableText(
                  value,
                  style: BTTypography.body(context),
                  contextMenuBuilder: buildContextMenu,
                ),
              ],
            ),
          ),
        );
      } else {
        value = replaceEscape(item.value as String);
        res.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    item.key,
                    style: BTTypography.bodyStrong(context),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    value,
                    style: BTTypography.body(context),
                    contextMenuBuilder: buildContextMenu,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: res,
    );
  }

  Widget buildContent() {
    if (data == null) return buildLoading();
    assert(data != null);
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BTFadeSlideIn(
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? BTColors.surfaceSecondary(context)
                    : BTColors.surfacePrimary(context),
                borderRadius: BTRadius.largeBR,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04),
                ),
                boxShadow: BTTheme.shadow(context, level: BTShadowLevel.medium),
              ),
              child: SdpOverviewWidget(data!, onTagTap: searchByTag),
            ),
          ),
          SizedBox(height: 12),

          if (hiveUser.user != null)
            BTFadeSlideIn(
              duration: const Duration(milliseconds: 350),
              delay: const Duration(milliseconds: 50),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BTColors.surfaceSecondary(context),
                  borderRadius: BTRadius.mediumBR,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: BsdUserCollection(
                        data!,
                        hiveUser.user!,
                        collectProvider,
                      ),
                    ),
                    SizedBox(width: 12),
                    _buildBmfDrawerButton(context),
                  ],
                ),
              ),
            ),

          BTFadeSlideIn(
            duration: const Duration(milliseconds: 400),
            delay: const Duration(milliseconds: 100),
            child: Expander(
              initiallyExpanded: true,
              leading: Icon(
                FluentIcons.video,
                size: 18,
                color: FluentTheme.of(context).accentColor,
              ),
              header: Text('剧集列表', style: BTTypography.subtitle(context)),
              content: BsdUserEpisodes(data!, hiveUser.user, collectProvider),
            ),
          ),

          BTFadeSlideIn(
            duration: const Duration(milliseconds: 450),
            delay: const Duration(milliseconds: 150),
            child: Expander(
              leading: Icon(
                FluentIcons.link,
                size: 18,
                color: FluentTheme.of(context).accentColor,
              ),
              header: Text('关联条目', style: BTTypography.subtitle(context)),
              content: SdpRelationWidget(data!.id),
            ),
          ),

          BTFadeSlideIn(
            duration: const Duration(milliseconds: 500),
            delay: const Duration(milliseconds: 200),
            child: Expander(
              initiallyExpanded: true,
              leading: Icon(
                FluentIcons.info,
                size: 18,
                color: FluentTheme.of(context).accentColor,
              ),
              header: Text('简介', style: BTTypography.subtitle(context)),
              content: buildSummary(data!.summary),
            ),
          ),

          BTFadeSlideIn(
            duration: const Duration(milliseconds: 550),
            delay: const Duration(milliseconds: 250),
            child: Expander(
              leading: Icon(
                FluentIcons.settings,
                size: 18,
                color: FluentTheme.of(context).accentColor,
              ),
              header: Text('详细信息', style: BTTypography.subtitle(context)),
              content: buildOtherInfo(data!.infobox),
            ),
          ),
        ],
      ),
    );
  }
}
