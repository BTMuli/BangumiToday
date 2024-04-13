import 'package:json_annotation/json_annotation.dart';

/// 从Bangumi API获取的数据枚举类，按照Bangumi API文档排列顺序排序
/// 详细文档请参考 https://bangumi.github.io/api/
/// 这边定义的枚举类，在 bangumi_enum_extension.dart 中有对应的扩展方法

/// Legacy_SubjectType
@JsonEnum(valueField: 'value')
enum BangumiLegacySubjectType {
  /// 书籍 1
  book(1),

  /// 动画 2
  anime(2),

  /// 音乐 3
  music(3),

  /// 游戏 4
  game(4),

  /// 三次元 6
  real(6);

  /// value
  final int value;

  const BangumiLegacySubjectType(this.value);
}

/// Legacy_EpisodeType
/// 因为这边的索引与定义索引一致，所以不需要扩展方法
@JsonEnum(valueField: 'value')
enum BangumiLegacyEpisodeType {
  /// 本篇 0
  main(0),

  /// 特别篇 1
  sp(1),

  /// OP 2
  op(2),

  /// ED 3
  ed(3),

  /// 预告/宣传/广告 4
  cm(4),

  /// MAD 5
  mad(5),

  /// 其他 6
  other(6);

  /// value
  final int value;

  const BangumiLegacyEpisodeType(this.value);
}

/// Legacy_UserGroup
@JsonEnum(valueField: 'value')
enum BangumiLegacyUserGroupType {
  /// 管理员 1
  admin(1),

  /// Bangumi管理员 2
  bangumiAdmin(2),

  /// 天窗管理员 3
  windowAdmin(3),

  /// 禁言用户 4
  mutedUser(4),

  /// 禁止访问用户 5
  bannedUser(5),

  /// 人物管理员 8
  personAdmin(8),

  /// 维基条目管理员 9
  wikiAdmin(9),

  /// 用户 10
  user(10),

  /// 维基人 11
  wikiUser(11);

  /// value
  final int value;

  const BangumiLegacyUserGroupType(this.value);
}

/// BloodType
@JsonEnum(valueField: 'value')
enum BangumiBloodType {
  /// A型 1
  a(1),

  /// B型 2
  b(2),

  /// AB型 3
  ab(3),

  /// O型 4
  o(4);

  /// value
  final int value;

  const BangumiBloodType(this.value);
}

/// CharacterType
@JsonEnum(valueField: 'value')
enum BangumiCharacterType {
  /// 角色 1
  character(1),

  /// 机体 2
  machine(2),

  /// 舰船 3
  ship(3),

  /// 组织 4
  group(4);

  /// value
  final int value;

  const BangumiCharacterType(this.value);
}

/// CollectionType
@JsonEnum(valueField: 'value')
enum BangumiCollectionType {
  /// 未知 0，用于处理未收藏的情况
  /// todo，该枚举值并未在Bangumi API文档中出现
  /// 但是为了便于处理未收藏的情况，故在这里定义
  unknown(0),

  /// 想看 1
  wish(1),

  /// 看过 2
  collect(2),

  /// 在看 3
  doing(3),

  /// 搁置 4
  onHold(4),

  /// 抛弃 5
  dropped(5);

  /// value
  final int value;

  const BangumiCollectionType(this.value);
}

/// EpisodeCollectionType
/// 因为这边的索引与定义索引一致，所以不需要扩展方法
@JsonEnum(valueField: 'value')
enum BangumiEpisodeCollectionType {
  /// 未收藏 0
  none(0),

  /// 想看 1
  wish(1),

  /// 看过 2
  done(2),

  /// 抛弃 3
  dropped(3);

  /// value
  final int value;

  const BangumiEpisodeCollectionType(this.value);
}

/// EpType
/// 定义与 LegacyEpisodeType 一致，同样不需要扩展方法
@JsonEnum(valueField: 'value')
enum BangumiEpType {
  /// 本篇 0
  main(0),

  /// 特别篇 1
  sp(1),

  /// OP 2
  op(2),

  /// ED 3
  ed(3),

  /// 预告/宣传/广告 4
  cm(4),

  /// MAD 5
  mad(5),

  /// 其他 6
  other(6);

  /// value
  final int value;

  const BangumiEpType(this.value);
}

/// PersonCareer
@JsonEnum(valueField: 'value')
enum BangumiPersonCareerType {
  /// producer producer
  producer('producer'),

  /// mangaka mangaka
  mangaka('mangaka'),

  /// artist artist
  artist('artist'),

  /// seiyu seiyu
  seiyu('seiyu'),

  /// writer writer
  writer('writer'),

  /// illustrator illustrator
  illustrator('illustrator'),

  /// actor actor
  actor('actor');

  /// value
  final String value;

  const BangumiPersonCareerType(this.value);
}

/// PersonType
@JsonEnum(valueField: 'value')
enum BangumiPersonType {
  /// 个人 1
  person(1),

  /// 公司 2
  company(2),

  /// 组合 3
  group(3);

  /// value
  final int value;

  const BangumiPersonType(this.value);
}

/// SubjectType
@JsonEnum(valueField: 'value')
enum BangumiSubjectType {
  /// 书籍 1
  book(1),

  /// 动画 2
  anime(2),

  /// 音乐 3
  music(3),

  /// 游戏 4
  game(4),

  /// 三次元 6
  real(6);

  /// value
  final int value;

  const BangumiSubjectType(this.value);
}

/// 下面的枚举类没有在Bangumi API文档中专门说明
/// 但是在Bangumi API返回的数据中有使用到，故在这里定义
/// 在 bangumi_enum_extension.dart 中有对应的扩展方法

/// LegacyEpisodeStatusType
@JsonEnum(valueField: 'value')
enum BangumiLegacyEpisodeStatusType {
  /// Air 已放送
  air('Air'),

  /// Today 正在放送
  today('Today'),

  /// NA 未放送
  na('NA');

  /// value
  final String value;

  const BangumiLegacyEpisodeStatusType(this.value);
}
