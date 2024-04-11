import 'bangumi_enum.dart';

/// 从Bangumi API获取的数据枚举类的拓展方法
/// 详细文档请参考 https://bangumi.github.io/api/
/// 枚举类见 bangumi_enum.dart

/// Legacy_SubjectType
extension BangumiLegacySubjectTypeExtension on BangumiLegacySubjectType {
  /// 获取值
  int get value {
    switch (this) {
      case BangumiLegacySubjectType.book:
        return 1;
      case BangumiLegacySubjectType.anime:
        return 2;
      case BangumiLegacySubjectType.music:
        return 3;
      case BangumiLegacySubjectType.game:
        return 4;
      case BangumiLegacySubjectType.real:
        return 6;
    }
  }
}

/// Legacy_EpisodeType
/// 因为索引与定义索引一致，所以不需要扩展方法

/// Legacy_UserGroup
extension BangumiLegacyUserGroupExtension on BangumiLegacyUserGroupType {
  /// 获取值
  int get value {
    switch (this) {
      case BangumiLegacyUserGroupType.admin:
        return 1;
      case BangumiLegacyUserGroupType.bangumiAdmin:
        return 2;
      case BangumiLegacyUserGroupType.windowAdmin:
        return 3;
      case BangumiLegacyUserGroupType.mutedUser:
        return 4;
      case BangumiLegacyUserGroupType.bannedUser:
        return 5;
      case BangumiLegacyUserGroupType.personAdmin:
        return 8;
      case BangumiLegacyUserGroupType.wikiAdmin:
        return 9;
      case BangumiLegacyUserGroupType.user:
        return 10;
      case BangumiLegacyUserGroupType.wikiUser:
        return 11;
    }
  }
}

/// BloodType
extension BangumiBloodTypeExtension on BangumiBloodType {
  /// 获取值
  int get value {
    switch (this) {
      case BangumiBloodType.a:
        return 1;
      case BangumiBloodType.b:
        return 2;
      case BangumiBloodType.ab:
        return 3;
      case BangumiBloodType.o:
        return 4;
    }
  }
}

/// CharacterType
extension BangumiCharacterTypeExtension on BangumiCharacterType {
  /// 获取值
  int get value {
    switch (this) {
      case BangumiCharacterType.character:
        return 1;
      case BangumiCharacterType.machine:
        return 2;
      case BangumiCharacterType.ship:
        return 3;
      case BangumiCharacterType.group:
        return 4;
    }
  }
}

/// CollectionType
extension BangumiCollectionTypeExtension on BangumiCollectionType {
  /// 获取值
  int get value {
    switch (this) {
      case BangumiCollectionType.wish:
        return 1;
      case BangumiCollectionType.collect:
        return 2;
      case BangumiCollectionType.doing:
        return 3;
      case BangumiCollectionType.onHold:
        return 4;
      case BangumiCollectionType.dropped:
        return 5;
    }
  }
}

/// EpisodeCollectionType
/// 因为这边的索引与定义索引一致，所以不需要扩展方法

/// EpType
/// 定义与 LegacySubjectType 一致，同样不需要扩展方法

/// PersonCareer
extension BangumiPersonCareerTypeExtension on BangumiPersonCareerType {
  /// 获取值
  String get value {
    switch (this) {
      case BangumiPersonCareerType.producer:
        return 'producer';
      case BangumiPersonCareerType.mangaka:
        return 'mangaka';
      case BangumiPersonCareerType.artist:
        return 'artist';
      case BangumiPersonCareerType.seiyu:
        return 'seiyu';
      case BangumiPersonCareerType.writer:
        return 'writer';
      case BangumiPersonCareerType.illustrator:
        return 'illustrator';
      case BangumiPersonCareerType.actor:
        return 'actor';
    }
  }
}

/// PersonType
extension BangumiPersonTypeExtension on BangumiPersonType {
  /// 获取值
  int get value {
    switch (this) {
      case BangumiPersonType.person:
        return 1;
      case BangumiPersonType.company:
        return 2;
      case BangumiPersonType.group:
        return 3;
    }
  }
}

/// SubjectType
extension BangumiSubjectTypeExtension on BangumiSubjectType {
  /// 获取值
  int get value {
    switch (this) {
      case BangumiSubjectType.book:
        return 1;
      case BangumiSubjectType.anime:
        return 2;
      case BangumiSubjectType.music:
        return 3;
      case BangumiSubjectType.game:
        return 4;
      case BangumiSubjectType.real:
        return 6;
    }
  }
}

/// 下面的枚举类没有在Bangumi API文档中专门说明
/// 但是在Bangumi API返回的数据中有使用到
/// 在 bangumi_enum.dart 中定义了这些枚举类，在这里进行拓展

/// LegacyEpisodeStatusType
extension BangumiLegacyEpisodeStatusTypeExtension
    on BangumiLegacyEpisodeStatusType {
  /// 获取值
  String get value {
    switch (this) {
      case BangumiLegacyEpisodeStatusType.air:
        return 'Air';
      case BangumiLegacyEpisodeStatusType.today:
        return 'Today';
      case BangumiLegacyEpisodeStatusType.na:
        return 'NA';
    }
  }
}
