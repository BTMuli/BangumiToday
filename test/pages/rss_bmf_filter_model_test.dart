import 'package:bangumi_today/database/app/app_rss.dart';
import 'package:bangumi_today/models/database/app_bmf_model.dart';
import 'package:bangumi_today/pages/rss-bmf/bmf_filter_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppBmfModel bmf({
    required int subject,
    String? title,
    String? rss,
    String? download,
    String? airDate,
    bool autoUpdate = true,
  }) {
    return AppBmfModel(
      subject: subject,
      title: title,
      rss: rss,
      download: download,
      airDate: airDate,
      autoUpdate: autoUpdate,
    );
  }

  List<AppBmfModel> seed() {
    return [
      bmf(
        subject: 1,
        title: 'A 番剧',
        rss: 'https://a.example/feed.xml',
        download: r'D:\A',
        airDate: '2026-02-10',
      ),
      bmf(
        subject: 2,
        title: 'B 番剧',
        rss: 'https://b.example/feed.xml',
        airDate: '2026-05-20',
        autoUpdate: false,
      ),
      bmf(subject: 3, title: 'C 番剧', download: r'D:\C', airDate: '2026-08-01'),
    ];
  }

  group('BmfFilterModel', () {
    test('computes configuration stats', () {
      var model = BmfFilterModel(rss: BtsAppRss());
      model.pendingCounts[1] = 2;

      model.computeStats(seed());

      expect(model.filterStats.total, 3);
      expect(model.filterStats.hasRss, 2);
      expect(model.filterStats.autoUpdate, 2);
      expect(model.filterStats.manualUpdate, 1);
      expect(model.filterStats.incomplete, 2);
      expect(model.filterStats.updates, 1);
    });

    test('derives quarter options and filters by quarter', () {
      var model = BmfFilterModel(rss: BtsAppRss());
      model.applyFilter(seed());

      expect(model.quarterOptions, contains(BmfQuarter(2026, 1)));
      expect(model.quarterOptions, contains(BmfQuarter(2026, 2)));
      expect(model.quarterOptions, contains(BmfQuarter(2026, 3)));
      expect(model.filteredList, hasLength(3));

      model.selectedQuarter = const BmfQuarter(2026, 2);
      model.applyFilter(seed());
      expect(model.filteredList.map((item) => item.subject), [2]);
    });

    test('filters by search query and configuration category', () {
      var model = BmfFilterModel(rss: BtsAppRss());
      model.pendingCounts[2] = 1;

      model.searchQuery = 'A';
      model.applyFilter(seed());
      expect(model.filteredList.map((item) => item.subject), [1]);

      model.searchQuery = '';
      model.configurationFilter = BmfConfigurationFilter.updates;
      model.applyFilter(seed());
      expect(model.filteredList.map((item) => item.subject), [2]);

      model.configurationFilter = BmfConfigurationFilter.incomplete;
      model.applyFilter(seed());
      expect(model.filteredList.map((item) => item.subject), [3, 2]);

      model.configurationFilter = BmfConfigurationFilter.manualUpdate;
      model.applyFilter(seed());
      expect(model.filteredList.map((item) => item.subject), [2]);

      model.configurationFilter = BmfConfigurationFilter.autoUpdate;
      model.applyFilter(seed());
      expect(model.filteredList.map((item) => item.subject), [3, 1]);

      model.configurationFilter = BmfConfigurationFilter.hasRss;
      model.applyFilter(seed());
      expect(model.filteredList.map((item) => item.subject), [2, 1]);
    });

    test('sorts by latest update time then falls back to air date', () {
      var model = BmfFilterModel(rss: BtsAppRss());
      model.latestUpdateTimes[2] = DateTime.utc(2026, 12, 1);

      model.applyFilter(seed());

      expect(model.filteredList.map((item) => item.subject), [2, 3, 1]);
    });

    test('maps RSS sources and reports whether status load is due', () {
      var model = BmfFilterModel(rss: BtsAppRss());
      var list = seed();

      expect(model.scheduleStatusLoad(list), isTrue);
      expect(model.rssSubjectsByKey['https://a.example/feed.xml'], 1);
      expect(model.rssSubjectsByKey['https://b.example/feed.xml'], 2);
      expect(model.scheduleStatusLoad(list), isFalse);

      list = [
        ...list,
        bmf(subject: 4, title: 'D', rss: 'https://d.example/feed.xml'),
      ];
      expect(model.scheduleStatusLoad(list), isTrue);
    });
  });
}
