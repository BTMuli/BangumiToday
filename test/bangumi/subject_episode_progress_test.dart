// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model_episode.dart';
import 'package:bangumi_today/pages/subject_detail/subject_episode_progress.dart';
import 'package:bangumi_today/pages/subject_detail/subject_stat_providers.dart';

BangumiEpisode _episode(int sort) => BangumiEpisode(
  id: 1000 + sort,
  type: BangumiEpType.main,
  name: 'episode $sort',
  nameCn: '',
  sort: sort.toDouble(),
  ep: (sort - 12).toDouble(),
  airDate: '',
  comment: 0,
  duration: '',
  desc: '',
  disc: 0,
  durationSeconds: 0,
);

void main() {
  var episodes = [for (var sort = 13; sort <= 24; sort++) _episode(sort)];
  var watched = {for (var episode in episodes) episode.id: true};

  test('episodes 13–24 count as twelve watched episodes', () {
    expect(summarizeSubjectEpisodes(episodes, watched), (
      done: 12,
      total: 12,
      complete: true,
    ));
  });

  test('counts individual states rather than the last watched number', () {
    var progress = {for (var episode in episodes) episode.id: false};
    progress[episodes.first.id] = true;
    progress[episodes.last.id] = true;
    expect(summarizeSubjectEpisodes(episodes, progress), (
      done: 2,
      total: 12,
      complete: true,
    ));
    progress[episodes.last.id] = false;
    expect(summarizeSubjectEpisodes(episodes, progress).done, 1);
  });

  test('ignores unrelated states and overlapping pagination entries', () {
    expect(
      summarizeSubjectEpisodes(
        [...episodes, episodes.first],
        {...watched, 9999: true},
      ),
      (done: 12, total: 12, complete: true),
    );
  });

  test('partial pages preserve the declared total and remain incomplete', () {
    expect(
      summarizeSubjectEpisodes(
        episodes.take(5),
        watched,
        complete: false,
        declaredTotal: 12,
      ),
      (done: 5, total: 12, complete: false),
    );
    expect(
      summarizeSubjectEpisodes(episodes.take(5), watched, complete: false),
      (done: 5, total: null, complete: false),
    );
  });

  test('missing chapter states cannot produce a complete count', () {
    expect(summarizeSubjectEpisodes(episodes, {episodes.first.id: true}), (
      done: 1,
      total: 12,
      complete: false,
    ));
  });

  test(
    'collection refreshes cannot replace the chapter count with ep_status',
    () {
      var provider = SubjectCollectStatProvider();
      addTearDown(provider.dispose);
      provider.set(true, epStatus: 24);
      provider.updateEpisodeProgress(
        summarizeSubjectEpisodes(episodes, watched),
      );
      provider.set(true, type: BangumiCollectionType.collect, epStatus: 24);
      expect(provider.episodeProgress, (done: 12, total: 12, complete: true));
      expect(provider.epStatus, 24);
      provider.set(false);
      expect(provider.episodeProgress, isNull);
    },
  );

  test('only changed chapter summaries notify listeners', () {
    var provider = SubjectCollectStatProvider();
    addTearDown(provider.dispose);
    var notifications = 0;
    provider.addListener(() => notifications++);
    provider.updateEpisodeProgress(summarizeSubjectEpisodes(episodes, watched));
    provider.updateEpisodeProgress(summarizeSubjectEpisodes(episodes, watched));
    expect(notifications, 1);
    provider.updateEpisodeProgress(
      summarizeSubjectEpisodes(episodes, {...watched, episodes.last.id: false}),
    );
    expect(notifications, 2);
    expect(provider.episodeProgress?.done, 11);
  });
}
