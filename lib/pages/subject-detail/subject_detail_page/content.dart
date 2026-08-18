part of '../subject_detail_page.dart';

extension _SubjectDetailContent on _SubjectDetailPageState {
  SubjectDetailViewData _viewData() {
    return SubjectDetailViewData(
      subject: data!,
      user: ref.watch(bgmUserHiveProvider).user,
      collectProvider: collectProvider,
      onTagTap: searchByTag,
      contextMenuBuilder: buildContextMenu,
      openBmfDrawer: _openBmfDrawer,
      collectionKey: _collectionKey,
      episodesKey: _episodesKey,
      relationsKey: _relationsKey,
    );
  }

  void _openBmfDrawer() {
    if (data == null) return;
    var subject = data!;
    var title = subject.nameCn.isEmpty ? subject.name : subject.nameCn;
    showBTDrawer(
      context: context,
      width: 420,
      child: BsdBmfDrawer(
        subjectId: subject.id,
        title: title,
        airDate: subject.date,
        rssProvider: rssProvider,
        onSearchMikan: searchBangumi,
      ),
    );
  }

  Widget buildContent() {
    if (data == null) return buildLoading();
    var view = _viewData();
    var mode = ref.watch(subjectDetailLayoutModeProvider);
    return switch (mode) {
      SubjectDetailLayoutMode.current => SdpLayoutCurrent(view: view),
      SubjectDetailLayoutMode.a => SdpLayoutA(view: view),
    };
  }
}
