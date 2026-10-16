// Project imports:
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_subject.dart';

/// Adapt the documented /p1 contract to the application's existing models.
/// https://github.com/bangumi/server-private/blob/master/openapi.json
class BangumiPrivateParser {
  static Map<String, dynamic> map(dynamic value) =>
      Map<String, dynamic>.from(value as Map);

  static Map<String, dynamic> images(dynamic value) => value == null
      ? {'large': '', 'common': '', 'medium': '', 'small': '', 'grid': ''}
      : map(value);

  static Map<String, dynamic> rating(dynamic value) {
    var json = map(value);
    var counts = json['count'] as List;
    return {
      'total': json['total'],
      'score': json['score'],
      'rank': json['rank'],
      'count': {for (var i = 0; i < counts.length; i++) '${i + 1}': counts[i]},
    };
  }

  static Map<String, dynamic> collection(dynamic value) {
    var json = value == null ? <String, dynamic>{} : map(value);
    return {
      'wish': json['1'],
      'collect': json['2'],
      'doing': json['3'],
      'on_hold': json['4'],
      'dropped': json['5'],
    };
  }

  static Map<String, dynamic> subjectJson(Map<String, dynamic> json) => {
    ...json,
    'name_cn': json['nameCN'],
    'images': images(json['images']),
    'date': json['airtime']?['date'],
    'platform': json['platform']?['typeCN'],
    'rating': rating(json['rating']),
    'collection': collection(json['collection']),
    'meta_tags': json['metaTags'],
    // SlimSubject does not expose the full summary, episode count or tags.
    'summary': json['summary'] ?? '',
    'series': json['series'] ?? false,
    'volumes': json['volumes'] ?? 0,
    'eps': json['eps'] ?? 0,
    'total_episodes': json['eps'],
    'tags': json['tags'] ?? const [],
    'infobox': [
      for (var item in json['infobox'] as List? ?? const [])
        {'key': item['key'], 'value': item['values']},
    ],
  };

  static BangumiSubject subject(dynamic value) {
    var json = subjectJson(map(value));
    // The full /p1 Subject contains both platform and eps.
    return BangumiSubject.fromJson(json);
  }

  static BangumiSubjectSearchData search(dynamic value) =>
      BangumiSubjectSearchData.fromJson(subjectJson(map(value)));

  static BangumiSlimSubject slimSubject(Map<String, dynamic> json) {
    var adapted = subjectJson(json);
    return BangumiSlimSubject.fromJson({
      ...adapted,
      'short_summary': json['summary'] ?? '',
      'collection_total': json['collection'] == null
          ? 0
          : map(json['collection']).values.fold<int>(
              0,
              (total, count) => total + (count as num).toInt(),
            ),
      'score': map(json['rating'])['score'],
    });
  }

  static BangumiUserSubjectCollection subjectCollection(dynamic value) {
    var json = map(value);
    var interest = map(json['interest']);
    return BangumiUserSubjectCollection.fromJson({
      'subject_id': json['id'],
      'subject_type': json['type'],
      'rate': interest['rate'],
      'type': interest['type'],
      'comment': interest['comment'],
      'tags': interest['tags'],
      'ep_status': interest['epStatus'],
      'vol_status': interest['volStatus'],
      'private': interest['private'],
      'updated_at': DateTime.fromMillisecondsSinceEpoch(
        (interest['updatedAt'] as num).toInt() * 1000,
        isUtc: true,
      ).toIso8601String(),
      'subject': slimSubject(json).toJson(),
    });
  }

  static BangumiEpisode episode(dynamic value) {
    var json = map(value);
    return BangumiEpisode.fromJson({
      ...json,
      'name_cn': json['nameCN'],
      // The gateway derives /v0-compatible ep from the complete chapter list.
      'ep': json['ep'] ?? 0,
      'duration_seconds': 0,
    });
  }

  static BangumiUserEpisodeCollection episodeCollection(dynamic value) {
    var json = map(value);
    return BangumiUserEpisodeCollection.fromJson({
      'episode': episode(json).toJson(),
      'type': json['collection']?['status'] ?? 0,
    });
  }

  static BangumiUser user(dynamic value) {
    var json = map(value);
    return BangumiUser.fromJson({...json, 'user_group': json['group']});
  }

  static BangumiSubjectRelation relation(dynamic value) {
    var json = map(value);
    var subject = map(json['subject']);
    return BangumiSubjectRelation.fromJson({
      ...subject,
      'name_cn': subject['nameCN'],
      'images': images(subject['images']),
      'relation': json['relation']['cn'],
    });
  }

  static Map<String, dynamic> personJson(dynamic value) {
    var json = map(value);
    return {...json, 'short_summary': json['info'], 'locked': json['lock']};
  }

  static BangumiRelatedCharacter character(dynamic value) {
    var json = map(value);
    var character = map(json['character']);
    return BangumiRelatedCharacter.fromJson({
      ...character,
      'type': character['role'],
      'relation': switch (json['type']) {
        1 => '主角',
        2 => '配角',
        3 => '客串',
        _ => '',
      },
      'actors': [
        for (var cast in json['casts'] as List) personJson(cast['person']),
      ],
    });
  }

  static Iterable<BangumiRelatedPerson> staff(dynamic value) sync* {
    var json = map(value);
    var person = map(json['staff']);
    for (var position in json['positions'] as List) {
      yield BangumiRelatedPerson.fromJson({
        ...person,
        'relation': position['type']['cn'],
        'eps': position['appearEps'],
      });
    }
  }

  static List<BangumiCalendarRespData> calendar(dynamic value) {
    const days = [
      ('Monday', '星期一', '月曜日'),
      ('Tuesday', '星期二', '火曜日'),
      ('Wednesday', '星期三', '水曜日'),
      ('Thursday', '星期四', '木曜日'),
      ('Friday', '星期五', '金曜日'),
      ('Saturday', '星期六', '土曜日'),
      ('Sunday', '星期日', '日曜日'),
    ];
    var json = map(value);
    return [
      for (var day = 1; day <= 7; day++)
        BangumiCalendarRespData.fromJson({
          'weekday': {
            'id': day,
            'en': days[day - 1].$1,
            'cn': days[day - 1].$2,
            'ja': days[day - 1].$3,
          },
          'items': [
            for (var item in json['$day'] as List? ?? const [])
              {
                ...subjectJson(map(item['subject'])),
                'url': 'https://bgm.tv/subject/${item['subject']['id']}',
                'air_date': '',
                'air_weekday': day,
                'rank': item['subject']['rating']['rank'],
                'collection': {'doing': item['watchers']},
              },
          ],
        }),
    ];
  }
}
