part of '../subject_detail_page.dart';

extension _SubjectDetailContent on _SubjectDetailPageState {
  SubjectDetailViewData _viewData() {
    return SubjectDetailViewData(
      subject: data!,
      user: ref.watch(bgmUserStoreProvider).user,
      collectProvider: collectProvider,
      onTagTap: searchByTag,
      onOpenEpisode: openEpisode,
      contextMenuBuilder: buildContextMenu,
      collectionKey: _collectionKey,
      episodesKey: _episodesKey,
      relationsKey: _relationsKey,
      charactersKey: _charactersKey,
      personsKey: _personsKey,
      commentsKey: _commentsKey,
      prefetch: _prefetch,
    );
  }

  Widget buildContent() {
    if (data == null) return buildLoading();
    var view = _viewData();
    var subject = data!;
    return SubjectDetailLayout(
      key: ValueKey('subject-layout-${subject.id}'),
      view: view,
      onRefreshRelations: () => _refreshSubModules(keys: [_relationsKey]),
      resources: SubjectDetailResources(
        key: _resourcesKey,
        subjectId: subject.id,
        title: subject.nameCn.isEmpty ? subject.name : subject.nameCn,
        airDate: subject.date,
        onSearchRss: searchRss,
      ),
    );
  }
}
