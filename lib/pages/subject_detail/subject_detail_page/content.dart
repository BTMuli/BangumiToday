part of '../subject_detail_page.dart';

extension _SubjectDetailContent on _SubjectDetailPageState {
  SubjectDetailViewData _viewData() {
    return SubjectDetailViewData(
      subject: data!,
      user: ref.watch(bgmUserStoreProvider).user,
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
      child: SubjectBmfDrawer(
        subjectId: subject.id,
        title: title,
        airDate: subject.date,
        onSearchRss: searchRss,
        rssProvider: rssProvider,
      ),
    );
  }

  Widget buildContent() {
    if (data == null) return buildLoading();
    var view = _viewData();
    var mode = ref.watch(subjectDetailLayoutModeProvider);
    return switch (mode) {
      SubjectDetailLayoutMode.current => SubjectDetailLayoutCurrent(view: view),
      SubjectDetailLayoutMode.a => SubjectDetailLayoutA(view: view),
    };
  }
}
