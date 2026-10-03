// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bt_database.dart';

// ignore_for_file: type=lint
class $AppBmfTable extends AppBmf with TableInfo<$AppBmfTable, BmfRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppBmfTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<int> subject = GeneratedColumn<int>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _rssMeta = const VerificationMeta('rss');
  @override
  late final GeneratedColumn<String> rss = GeneratedColumn<String>(
    'rss',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadMeta = const VerificationMeta(
    'download',
  );
  @override
  late final GeneratedColumn<String> download = GeneratedColumn<String>(
    'download',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mkBgmIdMeta = const VerificationMeta(
    'mkBgmId',
  );
  @override
  late final GeneratedColumn<String> mkBgmId = GeneratedColumn<String>(
    'mkBgmId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _mkGroupIdMeta = const VerificationMeta(
    'mkGroupId',
  );
  @override
  late final GeneratedColumn<String> mkGroupId = GeneratedColumn<String>(
    'mkGroupId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _airDateMeta = const VerificationMeta(
    'airDate',
  );
  @override
  late final GeneratedColumn<String> airDate = GeneratedColumn<String>(
    'airDate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _autoUpdateMeta = const VerificationMeta(
    'autoUpdate',
  );
  @override
  late final GeneratedColumn<int> autoUpdate = GeneratedColumn<int>(
    'autoUpdate',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subject,
    title,
    rss,
    download,
    mkBgmId,
    mkGroupId,
    airDate,
    autoUpdate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'AppBmf';
  @override
  VerificationContext validateIntegrity(
    Insertable<BmfRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('rss')) {
      context.handle(
        _rssMeta,
        rss.isAcceptableOrUnknown(data['rss']!, _rssMeta),
      );
    }
    if (data.containsKey('download')) {
      context.handle(
        _downloadMeta,
        download.isAcceptableOrUnknown(data['download']!, _downloadMeta),
      );
    }
    if (data.containsKey('mkBgmId')) {
      context.handle(
        _mkBgmIdMeta,
        mkBgmId.isAcceptableOrUnknown(data['mkBgmId']!, _mkBgmIdMeta),
      );
    }
    if (data.containsKey('mkGroupId')) {
      context.handle(
        _mkGroupIdMeta,
        mkGroupId.isAcceptableOrUnknown(data['mkGroupId']!, _mkGroupIdMeta),
      );
    }
    if (data.containsKey('airDate')) {
      context.handle(
        _airDateMeta,
        airDate.isAcceptableOrUnknown(data['airDate']!, _airDateMeta),
      );
    }
    if (data.containsKey('autoUpdate')) {
      context.handle(
        _autoUpdateMeta,
        autoUpdate.isAcceptableOrUnknown(data['autoUpdate']!, _autoUpdateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BmfRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BmfRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      rss: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rss'],
      ),
      download: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download'],
      ),
      mkBgmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mkBgmId'],
      ),
      mkGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mkGroupId'],
      ),
      airDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}airDate'],
      ),
      autoUpdate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}autoUpdate'],
      )!,
    );
  }

  @override
  $AppBmfTable createAlias(String alias) {
    return $AppBmfTable(attachedDatabase, alias);
  }
}

class BmfRow extends DataClass implements Insertable<BmfRow> {
  /// 自增主键
  final int id;

  /// bangumi subject id
  final int subject;

  /// bangumi subject title
  final String? title;

  /// RSS URL
  final String? rss;

  /// 下载目录
  final String? download;

  /// mikan bangumi id
  final String? mkBgmId;

  /// mikan group id
  final String? mkGroupId;

  /// 放送日期
  final String? airDate;

  /// 是否自动更新 RSS（0/1）
  final int autoUpdate;
  const BmfRow({
    required this.id,
    required this.subject,
    this.title,
    this.rss,
    this.download,
    this.mkBgmId,
    this.mkGroupId,
    this.airDate,
    required this.autoUpdate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject'] = Variable<int>(subject);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || rss != null) {
      map['rss'] = Variable<String>(rss);
    }
    if (!nullToAbsent || download != null) {
      map['download'] = Variable<String>(download);
    }
    if (!nullToAbsent || mkBgmId != null) {
      map['mkBgmId'] = Variable<String>(mkBgmId);
    }
    if (!nullToAbsent || mkGroupId != null) {
      map['mkGroupId'] = Variable<String>(mkGroupId);
    }
    if (!nullToAbsent || airDate != null) {
      map['airDate'] = Variable<String>(airDate);
    }
    map['autoUpdate'] = Variable<int>(autoUpdate);
    return map;
  }

  AppBmfCompanion toCompanion(bool nullToAbsent) {
    return AppBmfCompanion(
      id: Value(id),
      subject: Value(subject),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      rss: rss == null && nullToAbsent ? const Value.absent() : Value(rss),
      download: download == null && nullToAbsent
          ? const Value.absent()
          : Value(download),
      mkBgmId: mkBgmId == null && nullToAbsent
          ? const Value.absent()
          : Value(mkBgmId),
      mkGroupId: mkGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(mkGroupId),
      airDate: airDate == null && nullToAbsent
          ? const Value.absent()
          : Value(airDate),
      autoUpdate: Value(autoUpdate),
    );
  }

  factory BmfRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BmfRow(
      id: serializer.fromJson<int>(json['id']),
      subject: serializer.fromJson<int>(json['subject']),
      title: serializer.fromJson<String?>(json['title']),
      rss: serializer.fromJson<String?>(json['rss']),
      download: serializer.fromJson<String?>(json['download']),
      mkBgmId: serializer.fromJson<String?>(json['mkBgmId']),
      mkGroupId: serializer.fromJson<String?>(json['mkGroupId']),
      airDate: serializer.fromJson<String?>(json['airDate']),
      autoUpdate: serializer.fromJson<int>(json['autoUpdate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subject': serializer.toJson<int>(subject),
      'title': serializer.toJson<String?>(title),
      'rss': serializer.toJson<String?>(rss),
      'download': serializer.toJson<String?>(download),
      'mkBgmId': serializer.toJson<String?>(mkBgmId),
      'mkGroupId': serializer.toJson<String?>(mkGroupId),
      'airDate': serializer.toJson<String?>(airDate),
      'autoUpdate': serializer.toJson<int>(autoUpdate),
    };
  }

  BmfRow copyWith({
    int? id,
    int? subject,
    Value<String?> title = const Value.absent(),
    Value<String?> rss = const Value.absent(),
    Value<String?> download = const Value.absent(),
    Value<String?> mkBgmId = const Value.absent(),
    Value<String?> mkGroupId = const Value.absent(),
    Value<String?> airDate = const Value.absent(),
    int? autoUpdate,
  }) => BmfRow(
    id: id ?? this.id,
    subject: subject ?? this.subject,
    title: title.present ? title.value : this.title,
    rss: rss.present ? rss.value : this.rss,
    download: download.present ? download.value : this.download,
    mkBgmId: mkBgmId.present ? mkBgmId.value : this.mkBgmId,
    mkGroupId: mkGroupId.present ? mkGroupId.value : this.mkGroupId,
    airDate: airDate.present ? airDate.value : this.airDate,
    autoUpdate: autoUpdate ?? this.autoUpdate,
  );
  BmfRow copyWithCompanion(AppBmfCompanion data) {
    return BmfRow(
      id: data.id.present ? data.id.value : this.id,
      subject: data.subject.present ? data.subject.value : this.subject,
      title: data.title.present ? data.title.value : this.title,
      rss: data.rss.present ? data.rss.value : this.rss,
      download: data.download.present ? data.download.value : this.download,
      mkBgmId: data.mkBgmId.present ? data.mkBgmId.value : this.mkBgmId,
      mkGroupId: data.mkGroupId.present ? data.mkGroupId.value : this.mkGroupId,
      airDate: data.airDate.present ? data.airDate.value : this.airDate,
      autoUpdate: data.autoUpdate.present
          ? data.autoUpdate.value
          : this.autoUpdate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BmfRow(')
          ..write('id: $id, ')
          ..write('subject: $subject, ')
          ..write('title: $title, ')
          ..write('rss: $rss, ')
          ..write('download: $download, ')
          ..write('mkBgmId: $mkBgmId, ')
          ..write('mkGroupId: $mkGroupId, ')
          ..write('airDate: $airDate, ')
          ..write('autoUpdate: $autoUpdate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    subject,
    title,
    rss,
    download,
    mkBgmId,
    mkGroupId,
    airDate,
    autoUpdate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BmfRow &&
          other.id == this.id &&
          other.subject == this.subject &&
          other.title == this.title &&
          other.rss == this.rss &&
          other.download == this.download &&
          other.mkBgmId == this.mkBgmId &&
          other.mkGroupId == this.mkGroupId &&
          other.airDate == this.airDate &&
          other.autoUpdate == this.autoUpdate);
}

class AppBmfCompanion extends UpdateCompanion<BmfRow> {
  final Value<int> id;
  final Value<int> subject;
  final Value<String?> title;
  final Value<String?> rss;
  final Value<String?> download;
  final Value<String?> mkBgmId;
  final Value<String?> mkGroupId;
  final Value<String?> airDate;
  final Value<int> autoUpdate;
  const AppBmfCompanion({
    this.id = const Value.absent(),
    this.subject = const Value.absent(),
    this.title = const Value.absent(),
    this.rss = const Value.absent(),
    this.download = const Value.absent(),
    this.mkBgmId = const Value.absent(),
    this.mkGroupId = const Value.absent(),
    this.airDate = const Value.absent(),
    this.autoUpdate = const Value.absent(),
  });
  AppBmfCompanion.insert({
    this.id = const Value.absent(),
    required int subject,
    this.title = const Value.absent(),
    this.rss = const Value.absent(),
    this.download = const Value.absent(),
    this.mkBgmId = const Value.absent(),
    this.mkGroupId = const Value.absent(),
    this.airDate = const Value.absent(),
    this.autoUpdate = const Value.absent(),
  }) : subject = Value(subject);
  static Insertable<BmfRow> custom({
    Expression<int>? id,
    Expression<int>? subject,
    Expression<String>? title,
    Expression<String>? rss,
    Expression<String>? download,
    Expression<String>? mkBgmId,
    Expression<String>? mkGroupId,
    Expression<String>? airDate,
    Expression<int>? autoUpdate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subject != null) 'subject': subject,
      if (title != null) 'title': title,
      if (rss != null) 'rss': rss,
      if (download != null) 'download': download,
      if (mkBgmId != null) 'mkBgmId': mkBgmId,
      if (mkGroupId != null) 'mkGroupId': mkGroupId,
      if (airDate != null) 'airDate': airDate,
      if (autoUpdate != null) 'autoUpdate': autoUpdate,
    });
  }

  AppBmfCompanion copyWith({
    Value<int>? id,
    Value<int>? subject,
    Value<String?>? title,
    Value<String?>? rss,
    Value<String?>? download,
    Value<String?>? mkBgmId,
    Value<String?>? mkGroupId,
    Value<String?>? airDate,
    Value<int>? autoUpdate,
  }) {
    return AppBmfCompanion(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      title: title ?? this.title,
      rss: rss ?? this.rss,
      download: download ?? this.download,
      mkBgmId: mkBgmId ?? this.mkBgmId,
      mkGroupId: mkGroupId ?? this.mkGroupId,
      airDate: airDate ?? this.airDate,
      autoUpdate: autoUpdate ?? this.autoUpdate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subject.present) {
      map['subject'] = Variable<int>(subject.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (rss.present) {
      map['rss'] = Variable<String>(rss.value);
    }
    if (download.present) {
      map['download'] = Variable<String>(download.value);
    }
    if (mkBgmId.present) {
      map['mkBgmId'] = Variable<String>(mkBgmId.value);
    }
    if (mkGroupId.present) {
      map['mkGroupId'] = Variable<String>(mkGroupId.value);
    }
    if (airDate.present) {
      map['airDate'] = Variable<String>(airDate.value);
    }
    if (autoUpdate.present) {
      map['autoUpdate'] = Variable<int>(autoUpdate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppBmfCompanion(')
          ..write('id: $id, ')
          ..write('subject: $subject, ')
          ..write('title: $title, ')
          ..write('rss: $rss, ')
          ..write('download: $download, ')
          ..write('mkBgmId: $mkBgmId, ')
          ..write('mkGroupId: $mkGroupId, ')
          ..write('airDate: $airDate, ')
          ..write('autoUpdate: $autoUpdate')
          ..write(')'))
        .toString();
  }
}

class $AppRssTable extends AppRss with TableInfo<$AppRssTable, RssRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppRssTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rssMeta = const VerificationMeta('rss');
  @override
  late final GeneratedColumn<String> rss = GeneratedColumn<String>(
    'rss',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mkBgmIdMeta = const VerificationMeta(
    'mkBgmId',
  );
  @override
  late final GeneratedColumn<String> mkBgmId = GeneratedColumn<String>(
    'mkBgmId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mkGroupIdMeta = const VerificationMeta(
    'mkGroupId',
  );
  @override
  late final GeneratedColumn<String> mkGroupId = GeneratedColumn<String>(
    'mkGroupId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ttlMeta = const VerificationMeta('ttl');
  @override
  late final GeneratedColumn<int> ttl = GeneratedColumn<int>(
    'ttl',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedMeta = const VerificationMeta(
    'updated',
  );
  @override
  late final GeneratedColumn<int> updated = GeneratedColumn<int>(
    'updated',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pendingItemsMeta = const VerificationMeta(
    'pendingItems',
  );
  @override
  late final GeneratedColumn<String> pendingItems = GeneratedColumn<String>(
    'pendingItems',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _cacheVersionMeta = const VerificationMeta(
    'cacheVersion',
  );
  @override
  late final GeneratedColumn<int> cacheVersion = GeneratedColumn<int>(
    'cacheVersion',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastFailedMeta = const VerificationMeta(
    'lastFailed',
  );
  @override
  late final GeneratedColumn<int> lastFailed = GeneratedColumn<int>(
    'lastFailed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    rss,
    data,
    mkBgmId,
    mkGroupId,
    ttl,
    updated,
    pendingItems,
    cacheVersion,
    lastFailed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'AppRss';
  @override
  VerificationContext validateIntegrity(
    Insertable<RssRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('rss')) {
      context.handle(
        _rssMeta,
        rss.isAcceptableOrUnknown(data['rss']!, _rssMeta),
      );
    } else if (isInserting) {
      context.missing(_rssMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    }
    if (data.containsKey('mkBgmId')) {
      context.handle(
        _mkBgmIdMeta,
        mkBgmId.isAcceptableOrUnknown(data['mkBgmId']!, _mkBgmIdMeta),
      );
    }
    if (data.containsKey('mkGroupId')) {
      context.handle(
        _mkGroupIdMeta,
        mkGroupId.isAcceptableOrUnknown(data['mkGroupId']!, _mkGroupIdMeta),
      );
    }
    if (data.containsKey('ttl')) {
      context.handle(
        _ttlMeta,
        ttl.isAcceptableOrUnknown(data['ttl']!, _ttlMeta),
      );
    } else if (isInserting) {
      context.missing(_ttlMeta);
    }
    if (data.containsKey('updated')) {
      context.handle(
        _updatedMeta,
        updated.isAcceptableOrUnknown(data['updated']!, _updatedMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedMeta);
    }
    if (data.containsKey('pendingItems')) {
      context.handle(
        _pendingItemsMeta,
        pendingItems.isAcceptableOrUnknown(
          data['pendingItems']!,
          _pendingItemsMeta,
        ),
      );
    }
    if (data.containsKey('cacheVersion')) {
      context.handle(
        _cacheVersionMeta,
        cacheVersion.isAcceptableOrUnknown(
          data['cacheVersion']!,
          _cacheVersionMeta,
        ),
      );
    }
    if (data.containsKey('lastFailed')) {
      context.handle(
        _lastFailedMeta,
        lastFailed.isAcceptableOrUnknown(data['lastFailed']!, _lastFailedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rss};
  @override
  RssRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RssRow(
      rss: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rss'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      ),
      mkBgmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mkBgmId'],
      ),
      mkGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mkGroupId'],
      ),
      ttl: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ttl'],
      )!,
      updated: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated'],
      )!,
      pendingItems: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pendingItems'],
      )!,
      cacheVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cacheVersion'],
      )!,
      lastFailed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lastFailed'],
      )!,
    );
  }

  @override
  $AppRssTable createAlias(String alias) {
    return $AppRssTable(attachedDatabase, alias);
  }
}

class RssRow extends DataClass implements Insertable<RssRow> {
  /// RSS URL（主键）
  final String rss;

  /// RSS 数据
  final String? data;

  /// mikan bangumi id
  final String? mkBgmId;

  /// mikan group id
  final String? mkGroupId;

  /// ttl
  final int ttl;

  /// 最近更新时间（epoch 毫秒）
  final int updated;

  /// RSS 更新后尚未由用户处理的条目标识（JSON 文本）
  final String pendingItems;

  /// 缓存版本
  final int cacheVersion;

  /// 最近一次刷新失败时间（epoch 毫秒），0 表示无失败
  final int lastFailed;
  const RssRow({
    required this.rss,
    this.data,
    this.mkBgmId,
    this.mkGroupId,
    required this.ttl,
    required this.updated,
    required this.pendingItems,
    required this.cacheVersion,
    required this.lastFailed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['rss'] = Variable<String>(rss);
    if (!nullToAbsent || data != null) {
      map['data'] = Variable<String>(data);
    }
    if (!nullToAbsent || mkBgmId != null) {
      map['mkBgmId'] = Variable<String>(mkBgmId);
    }
    if (!nullToAbsent || mkGroupId != null) {
      map['mkGroupId'] = Variable<String>(mkGroupId);
    }
    map['ttl'] = Variable<int>(ttl);
    map['updated'] = Variable<int>(updated);
    map['pendingItems'] = Variable<String>(pendingItems);
    map['cacheVersion'] = Variable<int>(cacheVersion);
    map['lastFailed'] = Variable<int>(lastFailed);
    return map;
  }

  AppRssCompanion toCompanion(bool nullToAbsent) {
    return AppRssCompanion(
      rss: Value(rss),
      data: data == null && nullToAbsent ? const Value.absent() : Value(data),
      mkBgmId: mkBgmId == null && nullToAbsent
          ? const Value.absent()
          : Value(mkBgmId),
      mkGroupId: mkGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(mkGroupId),
      ttl: Value(ttl),
      updated: Value(updated),
      pendingItems: Value(pendingItems),
      cacheVersion: Value(cacheVersion),
      lastFailed: Value(lastFailed),
    );
  }

  factory RssRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RssRow(
      rss: serializer.fromJson<String>(json['rss']),
      data: serializer.fromJson<String?>(json['data']),
      mkBgmId: serializer.fromJson<String?>(json['mkBgmId']),
      mkGroupId: serializer.fromJson<String?>(json['mkGroupId']),
      ttl: serializer.fromJson<int>(json['ttl']),
      updated: serializer.fromJson<int>(json['updated']),
      pendingItems: serializer.fromJson<String>(json['pendingItems']),
      cacheVersion: serializer.fromJson<int>(json['cacheVersion']),
      lastFailed: serializer.fromJson<int>(json['lastFailed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rss': serializer.toJson<String>(rss),
      'data': serializer.toJson<String?>(data),
      'mkBgmId': serializer.toJson<String?>(mkBgmId),
      'mkGroupId': serializer.toJson<String?>(mkGroupId),
      'ttl': serializer.toJson<int>(ttl),
      'updated': serializer.toJson<int>(updated),
      'pendingItems': serializer.toJson<String>(pendingItems),
      'cacheVersion': serializer.toJson<int>(cacheVersion),
      'lastFailed': serializer.toJson<int>(lastFailed),
    };
  }

  RssRow copyWith({
    String? rss,
    Value<String?> data = const Value.absent(),
    Value<String?> mkBgmId = const Value.absent(),
    Value<String?> mkGroupId = const Value.absent(),
    int? ttl,
    int? updated,
    String? pendingItems,
    int? cacheVersion,
    int? lastFailed,
  }) => RssRow(
    rss: rss ?? this.rss,
    data: data.present ? data.value : this.data,
    mkBgmId: mkBgmId.present ? mkBgmId.value : this.mkBgmId,
    mkGroupId: mkGroupId.present ? mkGroupId.value : this.mkGroupId,
    ttl: ttl ?? this.ttl,
    updated: updated ?? this.updated,
    pendingItems: pendingItems ?? this.pendingItems,
    cacheVersion: cacheVersion ?? this.cacheVersion,
    lastFailed: lastFailed ?? this.lastFailed,
  );
  RssRow copyWithCompanion(AppRssCompanion data) {
    return RssRow(
      rss: data.rss.present ? data.rss.value : this.rss,
      data: data.data.present ? data.data.value : this.data,
      mkBgmId: data.mkBgmId.present ? data.mkBgmId.value : this.mkBgmId,
      mkGroupId: data.mkGroupId.present ? data.mkGroupId.value : this.mkGroupId,
      ttl: data.ttl.present ? data.ttl.value : this.ttl,
      updated: data.updated.present ? data.updated.value : this.updated,
      pendingItems: data.pendingItems.present
          ? data.pendingItems.value
          : this.pendingItems,
      cacheVersion: data.cacheVersion.present
          ? data.cacheVersion.value
          : this.cacheVersion,
      lastFailed: data.lastFailed.present
          ? data.lastFailed.value
          : this.lastFailed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RssRow(')
          ..write('rss: $rss, ')
          ..write('data: $data, ')
          ..write('mkBgmId: $mkBgmId, ')
          ..write('mkGroupId: $mkGroupId, ')
          ..write('ttl: $ttl, ')
          ..write('updated: $updated, ')
          ..write('pendingItems: $pendingItems, ')
          ..write('cacheVersion: $cacheVersion, ')
          ..write('lastFailed: $lastFailed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    rss,
    data,
    mkBgmId,
    mkGroupId,
    ttl,
    updated,
    pendingItems,
    cacheVersion,
    lastFailed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RssRow &&
          other.rss == this.rss &&
          other.data == this.data &&
          other.mkBgmId == this.mkBgmId &&
          other.mkGroupId == this.mkGroupId &&
          other.ttl == this.ttl &&
          other.updated == this.updated &&
          other.pendingItems == this.pendingItems &&
          other.cacheVersion == this.cacheVersion &&
          other.lastFailed == this.lastFailed);
}

class AppRssCompanion extends UpdateCompanion<RssRow> {
  final Value<String> rss;
  final Value<String?> data;
  final Value<String?> mkBgmId;
  final Value<String?> mkGroupId;
  final Value<int> ttl;
  final Value<int> updated;
  final Value<String> pendingItems;
  final Value<int> cacheVersion;
  final Value<int> lastFailed;
  final Value<int> rowid;
  const AppRssCompanion({
    this.rss = const Value.absent(),
    this.data = const Value.absent(),
    this.mkBgmId = const Value.absent(),
    this.mkGroupId = const Value.absent(),
    this.ttl = const Value.absent(),
    this.updated = const Value.absent(),
    this.pendingItems = const Value.absent(),
    this.cacheVersion = const Value.absent(),
    this.lastFailed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppRssCompanion.insert({
    required String rss,
    this.data = const Value.absent(),
    this.mkBgmId = const Value.absent(),
    this.mkGroupId = const Value.absent(),
    required int ttl,
    required int updated,
    this.pendingItems = const Value.absent(),
    this.cacheVersion = const Value.absent(),
    this.lastFailed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : rss = Value(rss),
       ttl = Value(ttl),
       updated = Value(updated);
  static Insertable<RssRow> custom({
    Expression<String>? rss,
    Expression<String>? data,
    Expression<String>? mkBgmId,
    Expression<String>? mkGroupId,
    Expression<int>? ttl,
    Expression<int>? updated,
    Expression<String>? pendingItems,
    Expression<int>? cacheVersion,
    Expression<int>? lastFailed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (rss != null) 'rss': rss,
      if (data != null) 'data': data,
      if (mkBgmId != null) 'mkBgmId': mkBgmId,
      if (mkGroupId != null) 'mkGroupId': mkGroupId,
      if (ttl != null) 'ttl': ttl,
      if (updated != null) 'updated': updated,
      if (pendingItems != null) 'pendingItems': pendingItems,
      if (cacheVersion != null) 'cacheVersion': cacheVersion,
      if (lastFailed != null) 'lastFailed': lastFailed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppRssCompanion copyWith({
    Value<String>? rss,
    Value<String?>? data,
    Value<String?>? mkBgmId,
    Value<String?>? mkGroupId,
    Value<int>? ttl,
    Value<int>? updated,
    Value<String>? pendingItems,
    Value<int>? cacheVersion,
    Value<int>? lastFailed,
    Value<int>? rowid,
  }) {
    return AppRssCompanion(
      rss: rss ?? this.rss,
      data: data ?? this.data,
      mkBgmId: mkBgmId ?? this.mkBgmId,
      mkGroupId: mkGroupId ?? this.mkGroupId,
      ttl: ttl ?? this.ttl,
      updated: updated ?? this.updated,
      pendingItems: pendingItems ?? this.pendingItems,
      cacheVersion: cacheVersion ?? this.cacheVersion,
      lastFailed: lastFailed ?? this.lastFailed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rss.present) {
      map['rss'] = Variable<String>(rss.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (mkBgmId.present) {
      map['mkBgmId'] = Variable<String>(mkBgmId.value);
    }
    if (mkGroupId.present) {
      map['mkGroupId'] = Variable<String>(mkGroupId.value);
    }
    if (ttl.present) {
      map['ttl'] = Variable<int>(ttl.value);
    }
    if (updated.present) {
      map['updated'] = Variable<int>(updated.value);
    }
    if (pendingItems.present) {
      map['pendingItems'] = Variable<String>(pendingItems.value);
    }
    if (cacheVersion.present) {
      map['cacheVersion'] = Variable<int>(cacheVersion.value);
    }
    if (lastFailed.present) {
      map['lastFailed'] = Variable<int>(lastFailed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppRssCompanion(')
          ..write('rss: $rss, ')
          ..write('data: $data, ')
          ..write('mkBgmId: $mkBgmId, ')
          ..write('mkGroupId: $mkGroupId, ')
          ..write('ttl: $ttl, ')
          ..write('updated: $updated, ')
          ..write('pendingItems: $pendingItems, ')
          ..write('cacheVersion: $cacheVersion, ')
          ..write('lastFailed: $lastFailed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppConfigTable extends AppConfig
    with TableInfo<$AppConfigTable, ConfigRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppConfigTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'AppConfig';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConfigRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  ConfigRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConfigRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppConfigTable createAlias(String alias) {
    return $AppConfigTable(attachedDatabase, alias);
  }
}

class ConfigRow extends DataClass implements Insertable<ConfigRow> {
  /// 配置键（主键）
  final String key;

  /// 配置值
  final String value;
  const ConfigRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppConfigCompanion toCompanion(bool nullToAbsent) {
    return AppConfigCompanion(key: Value(key), value: Value(value));
  }

  factory ConfigRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConfigRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  ConfigRow copyWith({String? key, String? value}) =>
      ConfigRow(key: key ?? this.key, value: value ?? this.value);
  ConfigRow copyWithCompanion(AppConfigCompanion data) {
    return ConfigRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConfigRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppConfigCompanion extends UpdateCompanion<ConfigRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppConfigCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppConfigCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<ConfigRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppConfigCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppConfigCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppConfigCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppPlaybackTable extends AppPlayback
    with TableInfo<$AppPlaybackTable, PlaybackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppPlaybackTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathKeyMeta = const VerificationMeta(
    'pathKey',
  );
  @override
  late final GeneratedColumn<String> pathKey = GeneratedColumn<String>(
    'pathKey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'filePath',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<int> subject = GeneratedColumn<int>(
    'subject',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'positionMs',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'durationMs',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<int> completed = GeneratedColumn<int>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updatedAt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    pathKey,
    filePath,
    title,
    subject,
    positionMs,
    durationMs,
    completed,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'AppPlayback';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pathKey')) {
      context.handle(
        _pathKeyMeta,
        pathKey.isAcceptableOrUnknown(data['pathKey']!, _pathKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pathKeyMeta);
    }
    if (data.containsKey('filePath')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['filePath']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    }
    if (data.containsKey('positionMs')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['positionMs']!, _positionMsMeta),
      );
    }
    if (data.containsKey('durationMs')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['durationMs']!, _durationMsMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('updatedAt')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updatedAt']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pathKey};
  @override
  PlaybackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackRow(
      pathKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pathKey'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filePath'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject'],
      ),
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}positionMs'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}durationMs'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updatedAt'],
      )!,
    );
  }

  @override
  $AppPlaybackTable createAlias(String alias) {
    return $AppPlaybackTable(attachedDatabase, alias);
  }
}

class PlaybackRow extends DataClass implements Insertable<PlaybackRow> {
  /// 规范化路径（主键）
  final String pathKey;

  /// 原始文件路径
  final String filePath;

  /// 显示标题
  final String title;

  /// 关联的 Bangumi 条目 ID
  final int? subject;

  /// 播放位置（毫秒）
  final int positionMs;

  /// 总时长（毫秒）
  final int durationMs;

  /// 是否已看完（0/1）
  final int completed;

  /// 最近更新时间（epoch 毫秒）
  final int updatedAt;
  const PlaybackRow({
    required this.pathKey,
    required this.filePath,
    required this.title,
    this.subject,
    required this.positionMs,
    required this.durationMs,
    required this.completed,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pathKey'] = Variable<String>(pathKey);
    map['filePath'] = Variable<String>(filePath);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || subject != null) {
      map['subject'] = Variable<int>(subject);
    }
    map['positionMs'] = Variable<int>(positionMs);
    map['durationMs'] = Variable<int>(durationMs);
    map['completed'] = Variable<int>(completed);
    map['updatedAt'] = Variable<int>(updatedAt);
    return map;
  }

  AppPlaybackCompanion toCompanion(bool nullToAbsent) {
    return AppPlaybackCompanion(
      pathKey: Value(pathKey),
      filePath: Value(filePath),
      title: Value(title),
      subject: subject == null && nullToAbsent
          ? const Value.absent()
          : Value(subject),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      completed: Value(completed),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackRow(
      pathKey: serializer.fromJson<String>(json['pathKey']),
      filePath: serializer.fromJson<String>(json['filePath']),
      title: serializer.fromJson<String>(json['title']),
      subject: serializer.fromJson<int?>(json['subject']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      completed: serializer.fromJson<int>(json['completed']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pathKey': serializer.toJson<String>(pathKey),
      'filePath': serializer.toJson<String>(filePath),
      'title': serializer.toJson<String>(title),
      'subject': serializer.toJson<int?>(subject),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'completed': serializer.toJson<int>(completed),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PlaybackRow copyWith({
    String? pathKey,
    String? filePath,
    String? title,
    Value<int?> subject = const Value.absent(),
    int? positionMs,
    int? durationMs,
    int? completed,
    int? updatedAt,
  }) => PlaybackRow(
    pathKey: pathKey ?? this.pathKey,
    filePath: filePath ?? this.filePath,
    title: title ?? this.title,
    subject: subject.present ? subject.value : this.subject,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    completed: completed ?? this.completed,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaybackRow copyWithCompanion(AppPlaybackCompanion data) {
    return PlaybackRow(
      pathKey: data.pathKey.present ? data.pathKey.value : this.pathKey,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      title: data.title.present ? data.title.value : this.title,
      subject: data.subject.present ? data.subject.value : this.subject,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      completed: data.completed.present ? data.completed.value : this.completed,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackRow(')
          ..write('pathKey: $pathKey, ')
          ..write('filePath: $filePath, ')
          ..write('title: $title, ')
          ..write('subject: $subject, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('completed: $completed, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    pathKey,
    filePath,
    title,
    subject,
    positionMs,
    durationMs,
    completed,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackRow &&
          other.pathKey == this.pathKey &&
          other.filePath == this.filePath &&
          other.title == this.title &&
          other.subject == this.subject &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.completed == this.completed &&
          other.updatedAt == this.updatedAt);
}

class AppPlaybackCompanion extends UpdateCompanion<PlaybackRow> {
  final Value<String> pathKey;
  final Value<String> filePath;
  final Value<String> title;
  final Value<int?> subject;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<int> completed;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AppPlaybackCompanion({
    this.pathKey = const Value.absent(),
    this.filePath = const Value.absent(),
    this.title = const Value.absent(),
    this.subject = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.completed = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppPlaybackCompanion.insert({
    required String pathKey,
    required String filePath,
    required String title,
    this.subject = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.completed = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : pathKey = Value(pathKey),
       filePath = Value(filePath),
       title = Value(title);
  static Insertable<PlaybackRow> custom({
    Expression<String>? pathKey,
    Expression<String>? filePath,
    Expression<String>? title,
    Expression<int>? subject,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<int>? completed,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pathKey != null) 'pathKey': pathKey,
      if (filePath != null) 'filePath': filePath,
      if (title != null) 'title': title,
      if (subject != null) 'subject': subject,
      if (positionMs != null) 'positionMs': positionMs,
      if (durationMs != null) 'durationMs': durationMs,
      if (completed != null) 'completed': completed,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppPlaybackCompanion copyWith({
    Value<String>? pathKey,
    Value<String>? filePath,
    Value<String>? title,
    Value<int?>? subject,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<int>? completed,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppPlaybackCompanion(
      pathKey: pathKey ?? this.pathKey,
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      completed: completed ?? this.completed,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pathKey.present) {
      map['pathKey'] = Variable<String>(pathKey.value);
    }
    if (filePath.present) {
      map['filePath'] = Variable<String>(filePath.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subject.present) {
      map['subject'] = Variable<int>(subject.value);
    }
    if (positionMs.present) {
      map['positionMs'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['durationMs'] = Variable<int>(durationMs.value);
    }
    if (completed.present) {
      map['completed'] = Variable<int>(completed.value);
    }
    if (updatedAt.present) {
      map['updatedAt'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppPlaybackCompanion(')
          ..write('pathKey: $pathKey, ')
          ..write('filePath: $filePath, ')
          ..write('title: $title, ')
          ..write('subject: $subject, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('completed: $completed, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BangumiUserTable extends BangumiUser
    with TableInfo<$BangumiUserTable, UserRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BangumiUserTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'BangumiUser';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  UserRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $BangumiUserTable createAlias(String alias) {
    return $BangumiUserTable(attachedDatabase, alias);
  }
}

class UserRow extends DataClass implements Insertable<UserRow> {
  /// 键（主键）：user / expireTime / accessToken / refreshToken
  final String key;

  /// 值
  final String value;
  const UserRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  BangumiUserCompanion toCompanion(bool nullToAbsent) {
    return BangumiUserCompanion(key: Value(key), value: Value(value));
  }

  factory UserRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  UserRow copyWith({String? key, String? value}) =>
      UserRow(key: key ?? this.key, value: value ?? this.value);
  UserRow copyWithCompanion(BangumiUserCompanion data) {
    return UserRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserRow && other.key == this.key && other.value == this.value);
}

class BangumiUserCompanion extends UpdateCompanion<UserRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const BangumiUserCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BangumiUserCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<UserRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BangumiUserCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return BangumiUserCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BangumiUserCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BangumiCollectionTable extends BangumiCollection
    with TableInfo<$BangumiCollectionTable, CollectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BangumiCollectionTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subjectId',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectTypeMeta = const VerificationMeta(
    'subjectType',
  );
  @override
  late final GeneratedColumn<int> subjectType = GeneratedColumn<int>(
    'subjectType',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  @override
  late final GeneratedColumn<int> rate = GeneratedColumn<int>(
    'rate',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _collectionTypeMeta = const VerificationMeta(
    'collectionType',
  );
  @override
  late final GeneratedColumn<int> collectionType = GeneratedColumn<int>(
    'collectionType',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _epStatMeta = const VerificationMeta('epStat');
  @override
  late final GeneratedColumn<int> epStat = GeneratedColumn<int>(
    'epStat',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _volStatMeta = const VerificationMeta(
    'volStat',
  );
  @override
  late final GeneratedColumn<int> volStat = GeneratedColumn<int>(
    'volStat',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updatedAt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _privateMeta = const VerificationMeta(
    'private',
  );
  @override
  late final GeneratedColumn<int> private = GeneratedColumn<int>(
    'private',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    subjectId,
    subjectType,
    rate,
    collectionType,
    comment,
    tags,
    epStat,
    volStat,
    updatedAt,
    private,
    subject,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'BangumiCollection';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('subjectId')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subjectId']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('subjectType')) {
      context.handle(
        _subjectTypeMeta,
        subjectType.isAcceptableOrUnknown(
          data['subjectType']!,
          _subjectTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectTypeMeta);
    }
    if (data.containsKey('rate')) {
      context.handle(
        _rateMeta,
        rate.isAcceptableOrUnknown(data['rate']!, _rateMeta),
      );
    } else if (isInserting) {
      context.missing(_rateMeta);
    }
    if (data.containsKey('collectionType')) {
      context.handle(
        _collectionTypeMeta,
        collectionType.isAcceptableOrUnknown(
          data['collectionType']!,
          _collectionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionTypeMeta);
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    } else if (isInserting) {
      context.missing(_tagsMeta);
    }
    if (data.containsKey('epStat')) {
      context.handle(
        _epStatMeta,
        epStat.isAcceptableOrUnknown(data['epStat']!, _epStatMeta),
      );
    } else if (isInserting) {
      context.missing(_epStatMeta);
    }
    if (data.containsKey('volStat')) {
      context.handle(
        _volStatMeta,
        volStat.isAcceptableOrUnknown(data['volStat']!, _volStatMeta),
      );
    } else if (isInserting) {
      context.missing(_volStatMeta);
    }
    if (data.containsKey('updatedAt')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updatedAt']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('private')) {
      context.handle(
        _privateMeta,
        private.isAcceptableOrUnknown(data['private']!, _privateMeta),
      );
    } else if (isInserting) {
      context.missing(_privateMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {subjectId};
  @override
  CollectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionRow(
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subjectId'],
      )!,
      subjectType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subjectType'],
      )!,
      rate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate'],
      )!,
      collectionType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}collectionType'],
      )!,
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      epStat: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}epStat'],
      )!,
      volStat: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}volStat'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updatedAt'],
      )!,
      private: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}private'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      ),
    );
  }

  @override
  $BangumiCollectionTable createAlias(String alias) {
    return $BangumiCollectionTable(attachedDatabase, alias);
  }
}

class CollectionRow extends DataClass implements Insertable<CollectionRow> {
  /// bangumi subject id（主键）
  final int subjectId;

  /// 条目类型
  final int subjectType;

  /// 评分
  final int rate;

  /// 收藏类型
  final int collectionType;

  /// 短评
  final String? comment;

  /// 标签（JSON 文本）
  final String tags;

  /// 已看话数
  final int epStat;

  /// 已看卷数
  final int volStat;

  /// 收藏更新时间（TEXT）
  final String updatedAt;

  /// 是否私密收藏（0/1）
  final int private;

  /// 条目数据（JSON 文本）
  final String? subject;
  const CollectionRow({
    required this.subjectId,
    required this.subjectType,
    required this.rate,
    required this.collectionType,
    this.comment,
    required this.tags,
    required this.epStat,
    required this.volStat,
    required this.updatedAt,
    required this.private,
    this.subject,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['subjectId'] = Variable<int>(subjectId);
    map['subjectType'] = Variable<int>(subjectType);
    map['rate'] = Variable<int>(rate);
    map['collectionType'] = Variable<int>(collectionType);
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    map['tags'] = Variable<String>(tags);
    map['epStat'] = Variable<int>(epStat);
    map['volStat'] = Variable<int>(volStat);
    map['updatedAt'] = Variable<String>(updatedAt);
    map['private'] = Variable<int>(private);
    if (!nullToAbsent || subject != null) {
      map['subject'] = Variable<String>(subject);
    }
    return map;
  }

  BangumiCollectionCompanion toCompanion(bool nullToAbsent) {
    return BangumiCollectionCompanion(
      subjectId: Value(subjectId),
      subjectType: Value(subjectType),
      rate: Value(rate),
      collectionType: Value(collectionType),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      tags: Value(tags),
      epStat: Value(epStat),
      volStat: Value(volStat),
      updatedAt: Value(updatedAt),
      private: Value(private),
      subject: subject == null && nullToAbsent
          ? const Value.absent()
          : Value(subject),
    );
  }

  factory CollectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionRow(
      subjectId: serializer.fromJson<int>(json['subjectId']),
      subjectType: serializer.fromJson<int>(json['subjectType']),
      rate: serializer.fromJson<int>(json['rate']),
      collectionType: serializer.fromJson<int>(json['collectionType']),
      comment: serializer.fromJson<String?>(json['comment']),
      tags: serializer.fromJson<String>(json['tags']),
      epStat: serializer.fromJson<int>(json['epStat']),
      volStat: serializer.fromJson<int>(json['volStat']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      private: serializer.fromJson<int>(json['private']),
      subject: serializer.fromJson<String?>(json['subject']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'subjectId': serializer.toJson<int>(subjectId),
      'subjectType': serializer.toJson<int>(subjectType),
      'rate': serializer.toJson<int>(rate),
      'collectionType': serializer.toJson<int>(collectionType),
      'comment': serializer.toJson<String?>(comment),
      'tags': serializer.toJson<String>(tags),
      'epStat': serializer.toJson<int>(epStat),
      'volStat': serializer.toJson<int>(volStat),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'private': serializer.toJson<int>(private),
      'subject': serializer.toJson<String?>(subject),
    };
  }

  CollectionRow copyWith({
    int? subjectId,
    int? subjectType,
    int? rate,
    int? collectionType,
    Value<String?> comment = const Value.absent(),
    String? tags,
    int? epStat,
    int? volStat,
    String? updatedAt,
    int? private,
    Value<String?> subject = const Value.absent(),
  }) => CollectionRow(
    subjectId: subjectId ?? this.subjectId,
    subjectType: subjectType ?? this.subjectType,
    rate: rate ?? this.rate,
    collectionType: collectionType ?? this.collectionType,
    comment: comment.present ? comment.value : this.comment,
    tags: tags ?? this.tags,
    epStat: epStat ?? this.epStat,
    volStat: volStat ?? this.volStat,
    updatedAt: updatedAt ?? this.updatedAt,
    private: private ?? this.private,
    subject: subject.present ? subject.value : this.subject,
  );
  CollectionRow copyWithCompanion(BangumiCollectionCompanion data) {
    return CollectionRow(
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      subjectType: data.subjectType.present
          ? data.subjectType.value
          : this.subjectType,
      rate: data.rate.present ? data.rate.value : this.rate,
      collectionType: data.collectionType.present
          ? data.collectionType.value
          : this.collectionType,
      comment: data.comment.present ? data.comment.value : this.comment,
      tags: data.tags.present ? data.tags.value : this.tags,
      epStat: data.epStat.present ? data.epStat.value : this.epStat,
      volStat: data.volStat.present ? data.volStat.value : this.volStat,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      private: data.private.present ? data.private.value : this.private,
      subject: data.subject.present ? data.subject.value : this.subject,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionRow(')
          ..write('subjectId: $subjectId, ')
          ..write('subjectType: $subjectType, ')
          ..write('rate: $rate, ')
          ..write('collectionType: $collectionType, ')
          ..write('comment: $comment, ')
          ..write('tags: $tags, ')
          ..write('epStat: $epStat, ')
          ..write('volStat: $volStat, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('private: $private, ')
          ..write('subject: $subject')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    subjectId,
    subjectType,
    rate,
    collectionType,
    comment,
    tags,
    epStat,
    volStat,
    updatedAt,
    private,
    subject,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionRow &&
          other.subjectId == this.subjectId &&
          other.subjectType == this.subjectType &&
          other.rate == this.rate &&
          other.collectionType == this.collectionType &&
          other.comment == this.comment &&
          other.tags == this.tags &&
          other.epStat == this.epStat &&
          other.volStat == this.volStat &&
          other.updatedAt == this.updatedAt &&
          other.private == this.private &&
          other.subject == this.subject);
}

class BangumiCollectionCompanion extends UpdateCompanion<CollectionRow> {
  final Value<int> subjectId;
  final Value<int> subjectType;
  final Value<int> rate;
  final Value<int> collectionType;
  final Value<String?> comment;
  final Value<String> tags;
  final Value<int> epStat;
  final Value<int> volStat;
  final Value<String> updatedAt;
  final Value<int> private;
  final Value<String?> subject;
  const BangumiCollectionCompanion({
    this.subjectId = const Value.absent(),
    this.subjectType = const Value.absent(),
    this.rate = const Value.absent(),
    this.collectionType = const Value.absent(),
    this.comment = const Value.absent(),
    this.tags = const Value.absent(),
    this.epStat = const Value.absent(),
    this.volStat = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.private = const Value.absent(),
    this.subject = const Value.absent(),
  });
  BangumiCollectionCompanion.insert({
    this.subjectId = const Value.absent(),
    required int subjectType,
    required int rate,
    required int collectionType,
    this.comment = const Value.absent(),
    required String tags,
    required int epStat,
    required int volStat,
    required String updatedAt,
    required int private,
    this.subject = const Value.absent(),
  }) : subjectType = Value(subjectType),
       rate = Value(rate),
       collectionType = Value(collectionType),
       tags = Value(tags),
       epStat = Value(epStat),
       volStat = Value(volStat),
       updatedAt = Value(updatedAt),
       private = Value(private);
  static Insertable<CollectionRow> custom({
    Expression<int>? subjectId,
    Expression<int>? subjectType,
    Expression<int>? rate,
    Expression<int>? collectionType,
    Expression<String>? comment,
    Expression<String>? tags,
    Expression<int>? epStat,
    Expression<int>? volStat,
    Expression<String>? updatedAt,
    Expression<int>? private,
    Expression<String>? subject,
  }) {
    return RawValuesInsertable({
      if (subjectId != null) 'subjectId': subjectId,
      if (subjectType != null) 'subjectType': subjectType,
      if (rate != null) 'rate': rate,
      if (collectionType != null) 'collectionType': collectionType,
      if (comment != null) 'comment': comment,
      if (tags != null) 'tags': tags,
      if (epStat != null) 'epStat': epStat,
      if (volStat != null) 'volStat': volStat,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (private != null) 'private': private,
      if (subject != null) 'subject': subject,
    });
  }

  BangumiCollectionCompanion copyWith({
    Value<int>? subjectId,
    Value<int>? subjectType,
    Value<int>? rate,
    Value<int>? collectionType,
    Value<String?>? comment,
    Value<String>? tags,
    Value<int>? epStat,
    Value<int>? volStat,
    Value<String>? updatedAt,
    Value<int>? private,
    Value<String?>? subject,
  }) {
    return BangumiCollectionCompanion(
      subjectId: subjectId ?? this.subjectId,
      subjectType: subjectType ?? this.subjectType,
      rate: rate ?? this.rate,
      collectionType: collectionType ?? this.collectionType,
      comment: comment ?? this.comment,
      tags: tags ?? this.tags,
      epStat: epStat ?? this.epStat,
      volStat: volStat ?? this.volStat,
      updatedAt: updatedAt ?? this.updatedAt,
      private: private ?? this.private,
      subject: subject ?? this.subject,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (subjectId.present) {
      map['subjectId'] = Variable<int>(subjectId.value);
    }
    if (subjectType.present) {
      map['subjectType'] = Variable<int>(subjectType.value);
    }
    if (rate.present) {
      map['rate'] = Variable<int>(rate.value);
    }
    if (collectionType.present) {
      map['collectionType'] = Variable<int>(collectionType.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (epStat.present) {
      map['epStat'] = Variable<int>(epStat.value);
    }
    if (volStat.present) {
      map['volStat'] = Variable<int>(volStat.value);
    }
    if (updatedAt.present) {
      map['updatedAt'] = Variable<String>(updatedAt.value);
    }
    if (private.present) {
      map['private'] = Variable<int>(private.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BangumiCollectionCompanion(')
          ..write('subjectId: $subjectId, ')
          ..write('subjectType: $subjectType, ')
          ..write('rate: $rate, ')
          ..write('collectionType: $collectionType, ')
          ..write('comment: $comment, ')
          ..write('tags: $tags, ')
          ..write('epStat: $epStat, ')
          ..write('volStat: $volStat, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('private: $private, ')
          ..write('subject: $subject')
          ..write(')'))
        .toString();
  }
}

class $BangumiDataSiteTable extends BangumiDataSite
    with TableInfo<$BangumiDataSiteTable, DataSiteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BangumiDataSiteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlTemplateMeta = const VerificationMeta(
    'urlTemplate',
  );
  @override
  late final GeneratedColumn<String> urlTemplate = GeneratedColumn<String>(
    'urlTemplate',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _regionsMeta = const VerificationMeta(
    'regions',
  );
  @override
  late final GeneratedColumn<String> regions = GeneratedColumn<String>(
    'regions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    key,
    title,
    urlTemplate,
    type,
    regions,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'BangumiDataSite';
  @override
  VerificationContext validateIntegrity(
    Insertable<DataSiteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('urlTemplate')) {
      context.handle(
        _urlTemplateMeta,
        urlTemplate.isAcceptableOrUnknown(
          data['urlTemplate']!,
          _urlTemplateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_urlTemplateMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('regions')) {
      context.handle(
        _regionsMeta,
        regions.isAcceptableOrUnknown(data['regions']!, _regionsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DataSiteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DataSiteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      urlTemplate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}urlTemplate'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      ),
      regions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}regions'],
      ),
    );
  }

  @override
  $BangumiDataSiteTable createAlias(String alias) {
    return $BangumiDataSiteTable(attachedDatabase, alias);
  }
}

class DataSiteRow extends DataClass implements Insertable<DataSiteRow> {
  /// 自增主键
  final int id;

  /// 站点键
  final String key;

  /// 站点标题
  final String title;

  /// URL 模板
  final String urlTemplate;

  /// 站点类型
  final String? type;

  /// 地区列表（JSON 文本）
  final String? regions;
  const DataSiteRow({
    required this.id,
    required this.key,
    required this.title,
    required this.urlTemplate,
    this.type,
    this.regions,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['key'] = Variable<String>(key);
    map['title'] = Variable<String>(title);
    map['urlTemplate'] = Variable<String>(urlTemplate);
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || regions != null) {
      map['regions'] = Variable<String>(regions);
    }
    return map;
  }

  BangumiDataSiteCompanion toCompanion(bool nullToAbsent) {
    return BangumiDataSiteCompanion(
      id: Value(id),
      key: Value(key),
      title: Value(title),
      urlTemplate: Value(urlTemplate),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      regions: regions == null && nullToAbsent
          ? const Value.absent()
          : Value(regions),
    );
  }

  factory DataSiteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DataSiteRow(
      id: serializer.fromJson<int>(json['id']),
      key: serializer.fromJson<String>(json['key']),
      title: serializer.fromJson<String>(json['title']),
      urlTemplate: serializer.fromJson<String>(json['urlTemplate']),
      type: serializer.fromJson<String?>(json['type']),
      regions: serializer.fromJson<String?>(json['regions']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'key': serializer.toJson<String>(key),
      'title': serializer.toJson<String>(title),
      'urlTemplate': serializer.toJson<String>(urlTemplate),
      'type': serializer.toJson<String?>(type),
      'regions': serializer.toJson<String?>(regions),
    };
  }

  DataSiteRow copyWith({
    int? id,
    String? key,
    String? title,
    String? urlTemplate,
    Value<String?> type = const Value.absent(),
    Value<String?> regions = const Value.absent(),
  }) => DataSiteRow(
    id: id ?? this.id,
    key: key ?? this.key,
    title: title ?? this.title,
    urlTemplate: urlTemplate ?? this.urlTemplate,
    type: type.present ? type.value : this.type,
    regions: regions.present ? regions.value : this.regions,
  );
  DataSiteRow copyWithCompanion(BangumiDataSiteCompanion data) {
    return DataSiteRow(
      id: data.id.present ? data.id.value : this.id,
      key: data.key.present ? data.key.value : this.key,
      title: data.title.present ? data.title.value : this.title,
      urlTemplate: data.urlTemplate.present
          ? data.urlTemplate.value
          : this.urlTemplate,
      type: data.type.present ? data.type.value : this.type,
      regions: data.regions.present ? data.regions.value : this.regions,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DataSiteRow(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('title: $title, ')
          ..write('urlTemplate: $urlTemplate, ')
          ..write('type: $type, ')
          ..write('regions: $regions')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, key, title, urlTemplate, type, regions);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DataSiteRow &&
          other.id == this.id &&
          other.key == this.key &&
          other.title == this.title &&
          other.urlTemplate == this.urlTemplate &&
          other.type == this.type &&
          other.regions == this.regions);
}

class BangumiDataSiteCompanion extends UpdateCompanion<DataSiteRow> {
  final Value<int> id;
  final Value<String> key;
  final Value<String> title;
  final Value<String> urlTemplate;
  final Value<String?> type;
  final Value<String?> regions;
  const BangumiDataSiteCompanion({
    this.id = const Value.absent(),
    this.key = const Value.absent(),
    this.title = const Value.absent(),
    this.urlTemplate = const Value.absent(),
    this.type = const Value.absent(),
    this.regions = const Value.absent(),
  });
  BangumiDataSiteCompanion.insert({
    this.id = const Value.absent(),
    required String key,
    required String title,
    required String urlTemplate,
    this.type = const Value.absent(),
    this.regions = const Value.absent(),
  }) : key = Value(key),
       title = Value(title),
       urlTemplate = Value(urlTemplate);
  static Insertable<DataSiteRow> custom({
    Expression<int>? id,
    Expression<String>? key,
    Expression<String>? title,
    Expression<String>? urlTemplate,
    Expression<String>? type,
    Expression<String>? regions,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (key != null) 'key': key,
      if (title != null) 'title': title,
      if (urlTemplate != null) 'urlTemplate': urlTemplate,
      if (type != null) 'type': type,
      if (regions != null) 'regions': regions,
    });
  }

  BangumiDataSiteCompanion copyWith({
    Value<int>? id,
    Value<String>? key,
    Value<String>? title,
    Value<String>? urlTemplate,
    Value<String?>? type,
    Value<String?>? regions,
  }) {
    return BangumiDataSiteCompanion(
      id: id ?? this.id,
      key: key ?? this.key,
      title: title ?? this.title,
      urlTemplate: urlTemplate ?? this.urlTemplate,
      type: type ?? this.type,
      regions: regions ?? this.regions,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (urlTemplate.present) {
      map['urlTemplate'] = Variable<String>(urlTemplate.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (regions.present) {
      map['regions'] = Variable<String>(regions.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BangumiDataSiteCompanion(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('title: $title, ')
          ..write('urlTemplate: $urlTemplate, ')
          ..write('type: $type, ')
          ..write('regions: $regions')
          ..write(')'))
        .toString();
  }
}

class $BangumiDataItemTable extends BangumiDataItem
    with TableInfo<$BangumiDataItemTable, DataItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BangumiDataItemTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleTranslateMeta = const VerificationMeta(
    'titleTranslate',
  );
  @override
  late final GeneratedColumn<String> titleTranslate = GeneratedColumn<String>(
    'titleTranslate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _langMeta = const VerificationMeta('lang');
  @override
  late final GeneratedColumn<String> lang = GeneratedColumn<String>(
    'lang',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _officialSiteMeta = const VerificationMeta(
    'officialSite',
  );
  @override
  late final GeneratedColumn<String> officialSite = GeneratedColumn<String>(
    'officialSite',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _beginMeta = const VerificationMeta('begin');
  @override
  late final GeneratedColumn<String> begin = GeneratedColumn<String>(
    'begin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _broadcastMeta = const VerificationMeta(
    'broadcast',
  );
  @override
  late final GeneratedColumn<String> broadcast = GeneratedColumn<String>(
    'broadcast',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endMeta = const VerificationMeta('end');
  @override
  late final GeneratedColumn<String> end = GeneratedColumn<String>(
    'end',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sitesMeta = const VerificationMeta('sites');
  @override
  late final GeneratedColumn<String> sites = GeneratedColumn<String>(
    'sites',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    titleTranslate,
    type,
    lang,
    officialSite,
    begin,
    broadcast,
    end,
    comment,
    sites,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'BangumiDataItem';
  @override
  VerificationContext validateIntegrity(
    Insertable<DataItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('titleTranslate')) {
      context.handle(
        _titleTranslateMeta,
        titleTranslate.isAcceptableOrUnknown(
          data['titleTranslate']!,
          _titleTranslateMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('lang')) {
      context.handle(
        _langMeta,
        lang.isAcceptableOrUnknown(data['lang']!, _langMeta),
      );
    }
    if (data.containsKey('officialSite')) {
      context.handle(
        _officialSiteMeta,
        officialSite.isAcceptableOrUnknown(
          data['officialSite']!,
          _officialSiteMeta,
        ),
      );
    }
    if (data.containsKey('begin')) {
      context.handle(
        _beginMeta,
        begin.isAcceptableOrUnknown(data['begin']!, _beginMeta),
      );
    }
    if (data.containsKey('broadcast')) {
      context.handle(
        _broadcastMeta,
        broadcast.isAcceptableOrUnknown(data['broadcast']!, _broadcastMeta),
      );
    }
    if (data.containsKey('end')) {
      context.handle(
        _endMeta,
        end.isAcceptableOrUnknown(data['end']!, _endMeta),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('sites')) {
      context.handle(
        _sitesMeta,
        sites.isAcceptableOrUnknown(data['sites']!, _sitesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DataItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DataItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      titleTranslate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}titleTranslate'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      ),
      lang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lang'],
      ),
      officialSite: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}officialSite'],
      ),
      begin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}begin'],
      ),
      broadcast: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}broadcast'],
      ),
      end: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end'],
      ),
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      sites: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sites'],
      ),
    );
  }

  @override
  $BangumiDataItemTable createAlias(String alias) {
    return $BangumiDataItemTable(attachedDatabase, alias);
  }
}

class DataItemRow extends DataClass implements Insertable<DataItemRow> {
  /// 自增主键
  final int id;

  /// 作品标题
  final String title;

  /// 标题翻译（JSON 文本）
  final String? titleTranslate;

  /// 条目类型
  final String? type;

  /// 语言
  final String? lang;

  /// 官网
  final String? officialSite;

  /// 开始日期
  final String? begin;

  /// 放送信息
  final String? broadcast;

  /// 结束日期
  final String? end;

  /// 备注
  final String? comment;

  /// 站点链接（JSON 文本）
  final String? sites;
  const DataItemRow({
    required this.id,
    required this.title,
    this.titleTranslate,
    this.type,
    this.lang,
    this.officialSite,
    this.begin,
    this.broadcast,
    this.end,
    this.comment,
    this.sites,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || titleTranslate != null) {
      map['titleTranslate'] = Variable<String>(titleTranslate);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || lang != null) {
      map['lang'] = Variable<String>(lang);
    }
    if (!nullToAbsent || officialSite != null) {
      map['officialSite'] = Variable<String>(officialSite);
    }
    if (!nullToAbsent || begin != null) {
      map['begin'] = Variable<String>(begin);
    }
    if (!nullToAbsent || broadcast != null) {
      map['broadcast'] = Variable<String>(broadcast);
    }
    if (!nullToAbsent || end != null) {
      map['end'] = Variable<String>(end);
    }
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    if (!nullToAbsent || sites != null) {
      map['sites'] = Variable<String>(sites);
    }
    return map;
  }

  BangumiDataItemCompanion toCompanion(bool nullToAbsent) {
    return BangumiDataItemCompanion(
      id: Value(id),
      title: Value(title),
      titleTranslate: titleTranslate == null && nullToAbsent
          ? const Value.absent()
          : Value(titleTranslate),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      lang: lang == null && nullToAbsent ? const Value.absent() : Value(lang),
      officialSite: officialSite == null && nullToAbsent
          ? const Value.absent()
          : Value(officialSite),
      begin: begin == null && nullToAbsent
          ? const Value.absent()
          : Value(begin),
      broadcast: broadcast == null && nullToAbsent
          ? const Value.absent()
          : Value(broadcast),
      end: end == null && nullToAbsent ? const Value.absent() : Value(end),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      sites: sites == null && nullToAbsent
          ? const Value.absent()
          : Value(sites),
    );
  }

  factory DataItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DataItemRow(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      titleTranslate: serializer.fromJson<String?>(json['titleTranslate']),
      type: serializer.fromJson<String?>(json['type']),
      lang: serializer.fromJson<String?>(json['lang']),
      officialSite: serializer.fromJson<String?>(json['officialSite']),
      begin: serializer.fromJson<String?>(json['begin']),
      broadcast: serializer.fromJson<String?>(json['broadcast']),
      end: serializer.fromJson<String?>(json['end']),
      comment: serializer.fromJson<String?>(json['comment']),
      sites: serializer.fromJson<String?>(json['sites']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'titleTranslate': serializer.toJson<String?>(titleTranslate),
      'type': serializer.toJson<String?>(type),
      'lang': serializer.toJson<String?>(lang),
      'officialSite': serializer.toJson<String?>(officialSite),
      'begin': serializer.toJson<String?>(begin),
      'broadcast': serializer.toJson<String?>(broadcast),
      'end': serializer.toJson<String?>(end),
      'comment': serializer.toJson<String?>(comment),
      'sites': serializer.toJson<String?>(sites),
    };
  }

  DataItemRow copyWith({
    int? id,
    String? title,
    Value<String?> titleTranslate = const Value.absent(),
    Value<String?> type = const Value.absent(),
    Value<String?> lang = const Value.absent(),
    Value<String?> officialSite = const Value.absent(),
    Value<String?> begin = const Value.absent(),
    Value<String?> broadcast = const Value.absent(),
    Value<String?> end = const Value.absent(),
    Value<String?> comment = const Value.absent(),
    Value<String?> sites = const Value.absent(),
  }) => DataItemRow(
    id: id ?? this.id,
    title: title ?? this.title,
    titleTranslate: titleTranslate.present
        ? titleTranslate.value
        : this.titleTranslate,
    type: type.present ? type.value : this.type,
    lang: lang.present ? lang.value : this.lang,
    officialSite: officialSite.present ? officialSite.value : this.officialSite,
    begin: begin.present ? begin.value : this.begin,
    broadcast: broadcast.present ? broadcast.value : this.broadcast,
    end: end.present ? end.value : this.end,
    comment: comment.present ? comment.value : this.comment,
    sites: sites.present ? sites.value : this.sites,
  );
  DataItemRow copyWithCompanion(BangumiDataItemCompanion data) {
    return DataItemRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      titleTranslate: data.titleTranslate.present
          ? data.titleTranslate.value
          : this.titleTranslate,
      type: data.type.present ? data.type.value : this.type,
      lang: data.lang.present ? data.lang.value : this.lang,
      officialSite: data.officialSite.present
          ? data.officialSite.value
          : this.officialSite,
      begin: data.begin.present ? data.begin.value : this.begin,
      broadcast: data.broadcast.present ? data.broadcast.value : this.broadcast,
      end: data.end.present ? data.end.value : this.end,
      comment: data.comment.present ? data.comment.value : this.comment,
      sites: data.sites.present ? data.sites.value : this.sites,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DataItemRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('titleTranslate: $titleTranslate, ')
          ..write('type: $type, ')
          ..write('lang: $lang, ')
          ..write('officialSite: $officialSite, ')
          ..write('begin: $begin, ')
          ..write('broadcast: $broadcast, ')
          ..write('end: $end, ')
          ..write('comment: $comment, ')
          ..write('sites: $sites')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    titleTranslate,
    type,
    lang,
    officialSite,
    begin,
    broadcast,
    end,
    comment,
    sites,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DataItemRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.titleTranslate == this.titleTranslate &&
          other.type == this.type &&
          other.lang == this.lang &&
          other.officialSite == this.officialSite &&
          other.begin == this.begin &&
          other.broadcast == this.broadcast &&
          other.end == this.end &&
          other.comment == this.comment &&
          other.sites == this.sites);
}

class BangumiDataItemCompanion extends UpdateCompanion<DataItemRow> {
  final Value<int> id;
  final Value<String> title;
  final Value<String?> titleTranslate;
  final Value<String?> type;
  final Value<String?> lang;
  final Value<String?> officialSite;
  final Value<String?> begin;
  final Value<String?> broadcast;
  final Value<String?> end;
  final Value<String?> comment;
  final Value<String?> sites;
  const BangumiDataItemCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.titleTranslate = const Value.absent(),
    this.type = const Value.absent(),
    this.lang = const Value.absent(),
    this.officialSite = const Value.absent(),
    this.begin = const Value.absent(),
    this.broadcast = const Value.absent(),
    this.end = const Value.absent(),
    this.comment = const Value.absent(),
    this.sites = const Value.absent(),
  });
  BangumiDataItemCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.titleTranslate = const Value.absent(),
    this.type = const Value.absent(),
    this.lang = const Value.absent(),
    this.officialSite = const Value.absent(),
    this.begin = const Value.absent(),
    this.broadcast = const Value.absent(),
    this.end = const Value.absent(),
    this.comment = const Value.absent(),
    this.sites = const Value.absent(),
  }) : title = Value(title);
  static Insertable<DataItemRow> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? titleTranslate,
    Expression<String>? type,
    Expression<String>? lang,
    Expression<String>? officialSite,
    Expression<String>? begin,
    Expression<String>? broadcast,
    Expression<String>? end,
    Expression<String>? comment,
    Expression<String>? sites,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (titleTranslate != null) 'titleTranslate': titleTranslate,
      if (type != null) 'type': type,
      if (lang != null) 'lang': lang,
      if (officialSite != null) 'officialSite': officialSite,
      if (begin != null) 'begin': begin,
      if (broadcast != null) 'broadcast': broadcast,
      if (end != null) 'end': end,
      if (comment != null) 'comment': comment,
      if (sites != null) 'sites': sites,
    });
  }

  BangumiDataItemCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String?>? titleTranslate,
    Value<String?>? type,
    Value<String?>? lang,
    Value<String?>? officialSite,
    Value<String?>? begin,
    Value<String?>? broadcast,
    Value<String?>? end,
    Value<String?>? comment,
    Value<String?>? sites,
  }) {
    return BangumiDataItemCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      titleTranslate: titleTranslate ?? this.titleTranslate,
      type: type ?? this.type,
      lang: lang ?? this.lang,
      officialSite: officialSite ?? this.officialSite,
      begin: begin ?? this.begin,
      broadcast: broadcast ?? this.broadcast,
      end: end ?? this.end,
      comment: comment ?? this.comment,
      sites: sites ?? this.sites,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (titleTranslate.present) {
      map['titleTranslate'] = Variable<String>(titleTranslate.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (lang.present) {
      map['lang'] = Variable<String>(lang.value);
    }
    if (officialSite.present) {
      map['officialSite'] = Variable<String>(officialSite.value);
    }
    if (begin.present) {
      map['begin'] = Variable<String>(begin.value);
    }
    if (broadcast.present) {
      map['broadcast'] = Variable<String>(broadcast.value);
    }
    if (end.present) {
      map['end'] = Variable<String>(end.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (sites.present) {
      map['sites'] = Variable<String>(sites.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BangumiDataItemCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('titleTranslate: $titleTranslate, ')
          ..write('type: $type, ')
          ..write('lang: $lang, ')
          ..write('officialSite: $officialSite, ')
          ..write('begin: $begin, ')
          ..write('broadcast: $broadcast, ')
          ..write('end: $end, ')
          ..write('comment: $comment, ')
          ..write('sites: $sites')
          ..write(')'))
        .toString();
  }
}

abstract class _$BtDatabase extends GeneratedDatabase {
  _$BtDatabase(QueryExecutor e) : super(e);
  $BtDatabaseManager get managers => $BtDatabaseManager(this);
  late final $AppBmfTable appBmf = $AppBmfTable(this);
  late final $AppRssTable appRss = $AppRssTable(this);
  late final $AppConfigTable appConfig = $AppConfigTable(this);
  late final $AppPlaybackTable appPlayback = $AppPlaybackTable(this);
  late final $BangumiUserTable bangumiUser = $BangumiUserTable(this);
  late final $BangumiCollectionTable bangumiCollection =
      $BangumiCollectionTable(this);
  late final $BangumiDataSiteTable bangumiDataSite = $BangumiDataSiteTable(
    this,
  );
  late final $BangumiDataItemTable bangumiDataItem = $BangumiDataItemTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appBmf,
    appRss,
    appConfig,
    appPlayback,
    bangumiUser,
    bangumiCollection,
    bangumiDataSite,
    bangumiDataItem,
  ];
}

typedef $$AppBmfTableCreateCompanionBuilder =
    AppBmfCompanion Function({
      Value<int> id,
      required int subject,
      Value<String?> title,
      Value<String?> rss,
      Value<String?> download,
      Value<String?> mkBgmId,
      Value<String?> mkGroupId,
      Value<String?> airDate,
      Value<int> autoUpdate,
    });
typedef $$AppBmfTableUpdateCompanionBuilder =
    AppBmfCompanion Function({
      Value<int> id,
      Value<int> subject,
      Value<String?> title,
      Value<String?> rss,
      Value<String?> download,
      Value<String?> mkBgmId,
      Value<String?> mkGroupId,
      Value<String?> airDate,
      Value<int> autoUpdate,
    });

class $$AppBmfTableFilterComposer extends Composer<_$BtDatabase, $AppBmfTable> {
  $$AppBmfTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rss => $composableBuilder(
    column: $table.rss,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get download => $composableBuilder(
    column: $table.download,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mkBgmId => $composableBuilder(
    column: $table.mkBgmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mkGroupId => $composableBuilder(
    column: $table.mkGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get autoUpdate => $composableBuilder(
    column: $table.autoUpdate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppBmfTableOrderingComposer
    extends Composer<_$BtDatabase, $AppBmfTable> {
  $$AppBmfTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rss => $composableBuilder(
    column: $table.rss,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get download => $composableBuilder(
    column: $table.download,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mkBgmId => $composableBuilder(
    column: $table.mkBgmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mkGroupId => $composableBuilder(
    column: $table.mkGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get autoUpdate => $composableBuilder(
    column: $table.autoUpdate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppBmfTableAnnotationComposer
    extends Composer<_$BtDatabase, $AppBmfTable> {
  $$AppBmfTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get rss =>
      $composableBuilder(column: $table.rss, builder: (column) => column);

  GeneratedColumn<String> get download =>
      $composableBuilder(column: $table.download, builder: (column) => column);

  GeneratedColumn<String> get mkBgmId =>
      $composableBuilder(column: $table.mkBgmId, builder: (column) => column);

  GeneratedColumn<String> get mkGroupId =>
      $composableBuilder(column: $table.mkGroupId, builder: (column) => column);

  GeneratedColumn<String> get airDate =>
      $composableBuilder(column: $table.airDate, builder: (column) => column);

  GeneratedColumn<int> get autoUpdate => $composableBuilder(
    column: $table.autoUpdate,
    builder: (column) => column,
  );
}

class $$AppBmfTableTableManager
    extends
        RootTableManager<
          _$BtDatabase,
          $AppBmfTable,
          BmfRow,
          $$AppBmfTableFilterComposer,
          $$AppBmfTableOrderingComposer,
          $$AppBmfTableAnnotationComposer,
          $$AppBmfTableCreateCompanionBuilder,
          $$AppBmfTableUpdateCompanionBuilder,
          (BmfRow, BaseReferences<_$BtDatabase, $AppBmfTable, BmfRow>),
          BmfRow,
          PrefetchHooks Function()
        > {
  $$AppBmfTableTableManager(_$BtDatabase db, $AppBmfTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppBmfTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppBmfTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppBmfTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> subject = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> rss = const Value.absent(),
                Value<String?> download = const Value.absent(),
                Value<String?> mkBgmId = const Value.absent(),
                Value<String?> mkGroupId = const Value.absent(),
                Value<String?> airDate = const Value.absent(),
                Value<int> autoUpdate = const Value.absent(),
              }) => AppBmfCompanion(
                id: id,
                subject: subject,
                title: title,
                rss: rss,
                download: download,
                mkBgmId: mkBgmId,
                mkGroupId: mkGroupId,
                airDate: airDate,
                autoUpdate: autoUpdate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subject,
                Value<String?> title = const Value.absent(),
                Value<String?> rss = const Value.absent(),
                Value<String?> download = const Value.absent(),
                Value<String?> mkBgmId = const Value.absent(),
                Value<String?> mkGroupId = const Value.absent(),
                Value<String?> airDate = const Value.absent(),
                Value<int> autoUpdate = const Value.absent(),
              }) => AppBmfCompanion.insert(
                id: id,
                subject: subject,
                title: title,
                rss: rss,
                download: download,
                mkBgmId: mkBgmId,
                mkGroupId: mkGroupId,
                airDate: airDate,
                autoUpdate: autoUpdate,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppBmfTable, BmfRow>(table),
                  BaseReferences<_$BtDatabase, $AppBmfTable, BmfRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppBmfTableProcessedTableManager =
    ProcessedTableManager<
      _$BtDatabase,
      $AppBmfTable,
      BmfRow,
      $$AppBmfTableFilterComposer,
      $$AppBmfTableOrderingComposer,
      $$AppBmfTableAnnotationComposer,
      $$AppBmfTableCreateCompanionBuilder,
      $$AppBmfTableUpdateCompanionBuilder,
      (BmfRow, BaseReferences<_$BtDatabase, $AppBmfTable, BmfRow>),
      BmfRow,
      PrefetchHooks Function()
    >;
typedef $$AppRssTableCreateCompanionBuilder =
    AppRssCompanion Function({
      required String rss,
      Value<String?> data,
      Value<String?> mkBgmId,
      Value<String?> mkGroupId,
      required int ttl,
      required int updated,
      Value<String> pendingItems,
      Value<int> cacheVersion,
      Value<int> lastFailed,
      Value<int> rowid,
    });
typedef $$AppRssTableUpdateCompanionBuilder =
    AppRssCompanion Function({
      Value<String> rss,
      Value<String?> data,
      Value<String?> mkBgmId,
      Value<String?> mkGroupId,
      Value<int> ttl,
      Value<int> updated,
      Value<String> pendingItems,
      Value<int> cacheVersion,
      Value<int> lastFailed,
      Value<int> rowid,
    });

class $$AppRssTableFilterComposer extends Composer<_$BtDatabase, $AppRssTable> {
  $$AppRssTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get rss => $composableBuilder(
    column: $table.rss,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mkBgmId => $composableBuilder(
    column: $table.mkBgmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mkGroupId => $composableBuilder(
    column: $table.mkGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updated => $composableBuilder(
    column: $table.updated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pendingItems => $composableBuilder(
    column: $table.pendingItems,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cacheVersion => $composableBuilder(
    column: $table.cacheVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastFailed => $composableBuilder(
    column: $table.lastFailed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppRssTableOrderingComposer
    extends Composer<_$BtDatabase, $AppRssTable> {
  $$AppRssTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get rss => $composableBuilder(
    column: $table.rss,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mkBgmId => $composableBuilder(
    column: $table.mkBgmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mkGroupId => $composableBuilder(
    column: $table.mkGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updated => $composableBuilder(
    column: $table.updated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingItems => $composableBuilder(
    column: $table.pendingItems,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cacheVersion => $composableBuilder(
    column: $table.cacheVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastFailed => $composableBuilder(
    column: $table.lastFailed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppRssTableAnnotationComposer
    extends Composer<_$BtDatabase, $AppRssTable> {
  $$AppRssTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get rss =>
      $composableBuilder(column: $table.rss, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get mkBgmId =>
      $composableBuilder(column: $table.mkBgmId, builder: (column) => column);

  GeneratedColumn<String> get mkGroupId =>
      $composableBuilder(column: $table.mkGroupId, builder: (column) => column);

  GeneratedColumn<int> get ttl =>
      $composableBuilder(column: $table.ttl, builder: (column) => column);

  GeneratedColumn<int> get updated =>
      $composableBuilder(column: $table.updated, builder: (column) => column);

  GeneratedColumn<String> get pendingItems => $composableBuilder(
    column: $table.pendingItems,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cacheVersion => $composableBuilder(
    column: $table.cacheVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastFailed => $composableBuilder(
    column: $table.lastFailed,
    builder: (column) => column,
  );
}

class $$AppRssTableTableManager
    extends
        RootTableManager<
          _$BtDatabase,
          $AppRssTable,
          RssRow,
          $$AppRssTableFilterComposer,
          $$AppRssTableOrderingComposer,
          $$AppRssTableAnnotationComposer,
          $$AppRssTableCreateCompanionBuilder,
          $$AppRssTableUpdateCompanionBuilder,
          (RssRow, BaseReferences<_$BtDatabase, $AppRssTable, RssRow>),
          RssRow,
          PrefetchHooks Function()
        > {
  $$AppRssTableTableManager(_$BtDatabase db, $AppRssTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppRssTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppRssTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppRssTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> rss = const Value.absent(),
                Value<String?> data = const Value.absent(),
                Value<String?> mkBgmId = const Value.absent(),
                Value<String?> mkGroupId = const Value.absent(),
                Value<int> ttl = const Value.absent(),
                Value<int> updated = const Value.absent(),
                Value<String> pendingItems = const Value.absent(),
                Value<int> cacheVersion = const Value.absent(),
                Value<int> lastFailed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppRssCompanion(
                rss: rss,
                data: data,
                mkBgmId: mkBgmId,
                mkGroupId: mkGroupId,
                ttl: ttl,
                updated: updated,
                pendingItems: pendingItems,
                cacheVersion: cacheVersion,
                lastFailed: lastFailed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String rss,
                Value<String?> data = const Value.absent(),
                Value<String?> mkBgmId = const Value.absent(),
                Value<String?> mkGroupId = const Value.absent(),
                required int ttl,
                required int updated,
                Value<String> pendingItems = const Value.absent(),
                Value<int> cacheVersion = const Value.absent(),
                Value<int> lastFailed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppRssCompanion.insert(
                rss: rss,
                data: data,
                mkBgmId: mkBgmId,
                mkGroupId: mkGroupId,
                ttl: ttl,
                updated: updated,
                pendingItems: pendingItems,
                cacheVersion: cacheVersion,
                lastFailed: lastFailed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppRssTable, RssRow>(table),
                  BaseReferences<_$BtDatabase, $AppRssTable, RssRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppRssTableProcessedTableManager =
    ProcessedTableManager<
      _$BtDatabase,
      $AppRssTable,
      RssRow,
      $$AppRssTableFilterComposer,
      $$AppRssTableOrderingComposer,
      $$AppRssTableAnnotationComposer,
      $$AppRssTableCreateCompanionBuilder,
      $$AppRssTableUpdateCompanionBuilder,
      (RssRow, BaseReferences<_$BtDatabase, $AppRssTable, RssRow>),
      RssRow,
      PrefetchHooks Function()
    >;
typedef $$AppConfigTableCreateCompanionBuilder =
    AppConfigCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppConfigTableUpdateCompanionBuilder =
    AppConfigCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppConfigTableFilterComposer
    extends Composer<_$BtDatabase, $AppConfigTable> {
  $$AppConfigTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppConfigTableOrderingComposer
    extends Composer<_$BtDatabase, $AppConfigTable> {
  $$AppConfigTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppConfigTableAnnotationComposer
    extends Composer<_$BtDatabase, $AppConfigTable> {
  $$AppConfigTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppConfigTableTableManager
    extends
        RootTableManager<
          _$BtDatabase,
          $AppConfigTable,
          ConfigRow,
          $$AppConfigTableFilterComposer,
          $$AppConfigTableOrderingComposer,
          $$AppConfigTableAnnotationComposer,
          $$AppConfigTableCreateCompanionBuilder,
          $$AppConfigTableUpdateCompanionBuilder,
          (ConfigRow, BaseReferences<_$BtDatabase, $AppConfigTable, ConfigRow>),
          ConfigRow,
          PrefetchHooks Function()
        > {
  $$AppConfigTableTableManager(_$BtDatabase db, $AppConfigTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppConfigTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppConfigTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppConfigTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppConfigCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppConfigCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppConfigTable, ConfigRow>(table),
                  BaseReferences<_$BtDatabase, $AppConfigTable, ConfigRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppConfigTableProcessedTableManager =
    ProcessedTableManager<
      _$BtDatabase,
      $AppConfigTable,
      ConfigRow,
      $$AppConfigTableFilterComposer,
      $$AppConfigTableOrderingComposer,
      $$AppConfigTableAnnotationComposer,
      $$AppConfigTableCreateCompanionBuilder,
      $$AppConfigTableUpdateCompanionBuilder,
      (ConfigRow, BaseReferences<_$BtDatabase, $AppConfigTable, ConfigRow>),
      ConfigRow,
      PrefetchHooks Function()
    >;
typedef $$AppPlaybackTableCreateCompanionBuilder =
    AppPlaybackCompanion Function({
      required String pathKey,
      required String filePath,
      required String title,
      Value<int?> subject,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<int> completed,
      Value<int> updatedAt,
      Value<int> rowid,
    });
typedef $$AppPlaybackTableUpdateCompanionBuilder =
    AppPlaybackCompanion Function({
      Value<String> pathKey,
      Value<String> filePath,
      Value<String> title,
      Value<int?> subject,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<int> completed,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$AppPlaybackTableFilterComposer
    extends Composer<_$BtDatabase, $AppPlaybackTable> {
  $$AppPlaybackTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pathKey => $composableBuilder(
    column: $table.pathKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppPlaybackTableOrderingComposer
    extends Composer<_$BtDatabase, $AppPlaybackTable> {
  $$AppPlaybackTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pathKey => $composableBuilder(
    column: $table.pathKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppPlaybackTableAnnotationComposer
    extends Composer<_$BtDatabase, $AppPlaybackTable> {
  $$AppPlaybackTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pathKey =>
      $composableBuilder(column: $table.pathKey, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppPlaybackTableTableManager
    extends
        RootTableManager<
          _$BtDatabase,
          $AppPlaybackTable,
          PlaybackRow,
          $$AppPlaybackTableFilterComposer,
          $$AppPlaybackTableOrderingComposer,
          $$AppPlaybackTableAnnotationComposer,
          $$AppPlaybackTableCreateCompanionBuilder,
          $$AppPlaybackTableUpdateCompanionBuilder,
          (
            PlaybackRow,
            BaseReferences<_$BtDatabase, $AppPlaybackTable, PlaybackRow>,
          ),
          PlaybackRow,
          PrefetchHooks Function()
        > {
  $$AppPlaybackTableTableManager(_$BtDatabase db, $AppPlaybackTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppPlaybackTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppPlaybackTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppPlaybackTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> pathKey = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> subject = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> completed = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppPlaybackCompanion(
                pathKey: pathKey,
                filePath: filePath,
                title: title,
                subject: subject,
                positionMs: positionMs,
                durationMs: durationMs,
                completed: completed,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pathKey,
                required String filePath,
                required String title,
                Value<int?> subject = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> completed = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppPlaybackCompanion.insert(
                pathKey: pathKey,
                filePath: filePath,
                title: title,
                subject: subject,
                positionMs: positionMs,
                durationMs: durationMs,
                completed: completed,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppPlaybackTable, PlaybackRow>(table),
                  BaseReferences<_$BtDatabase, $AppPlaybackTable, PlaybackRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppPlaybackTableProcessedTableManager =
    ProcessedTableManager<
      _$BtDatabase,
      $AppPlaybackTable,
      PlaybackRow,
      $$AppPlaybackTableFilterComposer,
      $$AppPlaybackTableOrderingComposer,
      $$AppPlaybackTableAnnotationComposer,
      $$AppPlaybackTableCreateCompanionBuilder,
      $$AppPlaybackTableUpdateCompanionBuilder,
      (
        PlaybackRow,
        BaseReferences<_$BtDatabase, $AppPlaybackTable, PlaybackRow>,
      ),
      PlaybackRow,
      PrefetchHooks Function()
    >;
typedef $$BangumiUserTableCreateCompanionBuilder =
    BangumiUserCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$BangumiUserTableUpdateCompanionBuilder =
    BangumiUserCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$BangumiUserTableFilterComposer
    extends Composer<_$BtDatabase, $BangumiUserTable> {
  $$BangumiUserTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BangumiUserTableOrderingComposer
    extends Composer<_$BtDatabase, $BangumiUserTable> {
  $$BangumiUserTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BangumiUserTableAnnotationComposer
    extends Composer<_$BtDatabase, $BangumiUserTable> {
  $$BangumiUserTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$BangumiUserTableTableManager
    extends
        RootTableManager<
          _$BtDatabase,
          $BangumiUserTable,
          UserRow,
          $$BangumiUserTableFilterComposer,
          $$BangumiUserTableOrderingComposer,
          $$BangumiUserTableAnnotationComposer,
          $$BangumiUserTableCreateCompanionBuilder,
          $$BangumiUserTableUpdateCompanionBuilder,
          (UserRow, BaseReferences<_$BtDatabase, $BangumiUserTable, UserRow>),
          UserRow,
          PrefetchHooks Function()
        > {
  $$BangumiUserTableTableManager(_$BtDatabase db, $BangumiUserTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BangumiUserTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BangumiUserTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BangumiUserTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BangumiUserCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => BangumiUserCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BangumiUserTable, UserRow>(table),
                  BaseReferences<_$BtDatabase, $BangumiUserTable, UserRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BangumiUserTableProcessedTableManager =
    ProcessedTableManager<
      _$BtDatabase,
      $BangumiUserTable,
      UserRow,
      $$BangumiUserTableFilterComposer,
      $$BangumiUserTableOrderingComposer,
      $$BangumiUserTableAnnotationComposer,
      $$BangumiUserTableCreateCompanionBuilder,
      $$BangumiUserTableUpdateCompanionBuilder,
      (UserRow, BaseReferences<_$BtDatabase, $BangumiUserTable, UserRow>),
      UserRow,
      PrefetchHooks Function()
    >;
typedef $$BangumiCollectionTableCreateCompanionBuilder =
    BangumiCollectionCompanion Function({
      Value<int> subjectId,
      required int subjectType,
      required int rate,
      required int collectionType,
      Value<String?> comment,
      required String tags,
      required int epStat,
      required int volStat,
      required String updatedAt,
      required int private,
      Value<String?> subject,
    });
typedef $$BangumiCollectionTableUpdateCompanionBuilder =
    BangumiCollectionCompanion Function({
      Value<int> subjectId,
      Value<int> subjectType,
      Value<int> rate,
      Value<int> collectionType,
      Value<String?> comment,
      Value<String> tags,
      Value<int> epStat,
      Value<int> volStat,
      Value<String> updatedAt,
      Value<int> private,
      Value<String?> subject,
    });

class $$BangumiCollectionTableFilterComposer
    extends Composer<_$BtDatabase, $BangumiCollectionTable> {
  $$BangumiCollectionTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get epStat => $composableBuilder(
    column: $table.epStat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get volStat => $composableBuilder(
    column: $table.volStat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get private => $composableBuilder(
    column: $table.private,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BangumiCollectionTableOrderingComposer
    extends Composer<_$BtDatabase, $BangumiCollectionTable> {
  $$BangumiCollectionTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get epStat => $composableBuilder(
    column: $table.epStat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get volStat => $composableBuilder(
    column: $table.volStat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get private => $composableBuilder(
    column: $table.private,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BangumiCollectionTableAnnotationComposer
    extends Composer<_$BtDatabase, $BangumiCollectionTable> {
  $$BangumiCollectionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<int> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rate =>
      $composableBuilder(column: $table.rate, builder: (column) => column);

  GeneratedColumn<int> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<int> get epStat =>
      $composableBuilder(column: $table.epStat, builder: (column) => column);

  GeneratedColumn<int> get volStat =>
      $composableBuilder(column: $table.volStat, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get private =>
      $composableBuilder(column: $table.private, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);
}

class $$BangumiCollectionTableTableManager
    extends
        RootTableManager<
          _$BtDatabase,
          $BangumiCollectionTable,
          CollectionRow,
          $$BangumiCollectionTableFilterComposer,
          $$BangumiCollectionTableOrderingComposer,
          $$BangumiCollectionTableAnnotationComposer,
          $$BangumiCollectionTableCreateCompanionBuilder,
          $$BangumiCollectionTableUpdateCompanionBuilder,
          (
            CollectionRow,
            BaseReferences<
              _$BtDatabase,
              $BangumiCollectionTable,
              CollectionRow
            >,
          ),
          CollectionRow,
          PrefetchHooks Function()
        > {
  $$BangumiCollectionTableTableManager(
    _$BtDatabase db,
    $BangumiCollectionTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BangumiCollectionTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BangumiCollectionTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BangumiCollectionTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> subjectId = const Value.absent(),
                Value<int> subjectType = const Value.absent(),
                Value<int> rate = const Value.absent(),
                Value<int> collectionType = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<int> epStat = const Value.absent(),
                Value<int> volStat = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> private = const Value.absent(),
                Value<String?> subject = const Value.absent(),
              }) => BangumiCollectionCompanion(
                subjectId: subjectId,
                subjectType: subjectType,
                rate: rate,
                collectionType: collectionType,
                comment: comment,
                tags: tags,
                epStat: epStat,
                volStat: volStat,
                updatedAt: updatedAt,
                private: private,
                subject: subject,
              ),
          createCompanionCallback:
              ({
                Value<int> subjectId = const Value.absent(),
                required int subjectType,
                required int rate,
                required int collectionType,
                Value<String?> comment = const Value.absent(),
                required String tags,
                required int epStat,
                required int volStat,
                required String updatedAt,
                required int private,
                Value<String?> subject = const Value.absent(),
              }) => BangumiCollectionCompanion.insert(
                subjectId: subjectId,
                subjectType: subjectType,
                rate: rate,
                collectionType: collectionType,
                comment: comment,
                tags: tags,
                epStat: epStat,
                volStat: volStat,
                updatedAt: updatedAt,
                private: private,
                subject: subject,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BangumiCollectionTable, CollectionRow>(table),
                  BaseReferences<
                    _$BtDatabase,
                    $BangumiCollectionTable,
                    CollectionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BangumiCollectionTableProcessedTableManager =
    ProcessedTableManager<
      _$BtDatabase,
      $BangumiCollectionTable,
      CollectionRow,
      $$BangumiCollectionTableFilterComposer,
      $$BangumiCollectionTableOrderingComposer,
      $$BangumiCollectionTableAnnotationComposer,
      $$BangumiCollectionTableCreateCompanionBuilder,
      $$BangumiCollectionTableUpdateCompanionBuilder,
      (
        CollectionRow,
        BaseReferences<_$BtDatabase, $BangumiCollectionTable, CollectionRow>,
      ),
      CollectionRow,
      PrefetchHooks Function()
    >;
typedef $$BangumiDataSiteTableCreateCompanionBuilder =
    BangumiDataSiteCompanion Function({
      Value<int> id,
      required String key,
      required String title,
      required String urlTemplate,
      Value<String?> type,
      Value<String?> regions,
    });
typedef $$BangumiDataSiteTableUpdateCompanionBuilder =
    BangumiDataSiteCompanion Function({
      Value<int> id,
      Value<String> key,
      Value<String> title,
      Value<String> urlTemplate,
      Value<String?> type,
      Value<String?> regions,
    });

class $$BangumiDataSiteTableFilterComposer
    extends Composer<_$BtDatabase, $BangumiDataSiteTable> {
  $$BangumiDataSiteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get urlTemplate => $composableBuilder(
    column: $table.urlTemplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get regions => $composableBuilder(
    column: $table.regions,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BangumiDataSiteTableOrderingComposer
    extends Composer<_$BtDatabase, $BangumiDataSiteTable> {
  $$BangumiDataSiteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get urlTemplate => $composableBuilder(
    column: $table.urlTemplate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get regions => $composableBuilder(
    column: $table.regions,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BangumiDataSiteTableAnnotationComposer
    extends Composer<_$BtDatabase, $BangumiDataSiteTable> {
  $$BangumiDataSiteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get urlTemplate => $composableBuilder(
    column: $table.urlTemplate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get regions =>
      $composableBuilder(column: $table.regions, builder: (column) => column);
}

class $$BangumiDataSiteTableTableManager
    extends
        RootTableManager<
          _$BtDatabase,
          $BangumiDataSiteTable,
          DataSiteRow,
          $$BangumiDataSiteTableFilterComposer,
          $$BangumiDataSiteTableOrderingComposer,
          $$BangumiDataSiteTableAnnotationComposer,
          $$BangumiDataSiteTableCreateCompanionBuilder,
          $$BangumiDataSiteTableUpdateCompanionBuilder,
          (
            DataSiteRow,
            BaseReferences<_$BtDatabase, $BangumiDataSiteTable, DataSiteRow>,
          ),
          DataSiteRow,
          PrefetchHooks Function()
        > {
  $$BangumiDataSiteTableTableManager(
    _$BtDatabase db,
    $BangumiDataSiteTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BangumiDataSiteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BangumiDataSiteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BangumiDataSiteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> urlTemplate = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> regions = const Value.absent(),
              }) => BangumiDataSiteCompanion(
                id: id,
                key: key,
                title: title,
                urlTemplate: urlTemplate,
                type: type,
                regions: regions,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String key,
                required String title,
                required String urlTemplate,
                Value<String?> type = const Value.absent(),
                Value<String?> regions = const Value.absent(),
              }) => BangumiDataSiteCompanion.insert(
                id: id,
                key: key,
                title: title,
                urlTemplate: urlTemplate,
                type: type,
                regions: regions,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BangumiDataSiteTable, DataSiteRow>(table),
                  BaseReferences<
                    _$BtDatabase,
                    $BangumiDataSiteTable,
                    DataSiteRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BangumiDataSiteTableProcessedTableManager =
    ProcessedTableManager<
      _$BtDatabase,
      $BangumiDataSiteTable,
      DataSiteRow,
      $$BangumiDataSiteTableFilterComposer,
      $$BangumiDataSiteTableOrderingComposer,
      $$BangumiDataSiteTableAnnotationComposer,
      $$BangumiDataSiteTableCreateCompanionBuilder,
      $$BangumiDataSiteTableUpdateCompanionBuilder,
      (
        DataSiteRow,
        BaseReferences<_$BtDatabase, $BangumiDataSiteTable, DataSiteRow>,
      ),
      DataSiteRow,
      PrefetchHooks Function()
    >;
typedef $$BangumiDataItemTableCreateCompanionBuilder =
    BangumiDataItemCompanion Function({
      Value<int> id,
      required String title,
      Value<String?> titleTranslate,
      Value<String?> type,
      Value<String?> lang,
      Value<String?> officialSite,
      Value<String?> begin,
      Value<String?> broadcast,
      Value<String?> end,
      Value<String?> comment,
      Value<String?> sites,
    });
typedef $$BangumiDataItemTableUpdateCompanionBuilder =
    BangumiDataItemCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String?> titleTranslate,
      Value<String?> type,
      Value<String?> lang,
      Value<String?> officialSite,
      Value<String?> begin,
      Value<String?> broadcast,
      Value<String?> end,
      Value<String?> comment,
      Value<String?> sites,
    });

class $$BangumiDataItemTableFilterComposer
    extends Composer<_$BtDatabase, $BangumiDataItemTable> {
  $$BangumiDataItemTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleTranslate => $composableBuilder(
    column: $table.titleTranslate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get officialSite => $composableBuilder(
    column: $table.officialSite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get begin => $composableBuilder(
    column: $table.begin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get broadcast => $composableBuilder(
    column: $table.broadcast,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get end => $composableBuilder(
    column: $table.end,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sites => $composableBuilder(
    column: $table.sites,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BangumiDataItemTableOrderingComposer
    extends Composer<_$BtDatabase, $BangumiDataItemTable> {
  $$BangumiDataItemTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleTranslate => $composableBuilder(
    column: $table.titleTranslate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get officialSite => $composableBuilder(
    column: $table.officialSite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get begin => $composableBuilder(
    column: $table.begin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get broadcast => $composableBuilder(
    column: $table.broadcast,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get end => $composableBuilder(
    column: $table.end,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sites => $composableBuilder(
    column: $table.sites,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BangumiDataItemTableAnnotationComposer
    extends Composer<_$BtDatabase, $BangumiDataItemTable> {
  $$BangumiDataItemTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get titleTranslate => $composableBuilder(
    column: $table.titleTranslate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get lang =>
      $composableBuilder(column: $table.lang, builder: (column) => column);

  GeneratedColumn<String> get officialSite => $composableBuilder(
    column: $table.officialSite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get begin =>
      $composableBuilder(column: $table.begin, builder: (column) => column);

  GeneratedColumn<String> get broadcast =>
      $composableBuilder(column: $table.broadcast, builder: (column) => column);

  GeneratedColumn<String> get end =>
      $composableBuilder(column: $table.end, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get sites =>
      $composableBuilder(column: $table.sites, builder: (column) => column);
}

class $$BangumiDataItemTableTableManager
    extends
        RootTableManager<
          _$BtDatabase,
          $BangumiDataItemTable,
          DataItemRow,
          $$BangumiDataItemTableFilterComposer,
          $$BangumiDataItemTableOrderingComposer,
          $$BangumiDataItemTableAnnotationComposer,
          $$BangumiDataItemTableCreateCompanionBuilder,
          $$BangumiDataItemTableUpdateCompanionBuilder,
          (
            DataItemRow,
            BaseReferences<_$BtDatabase, $BangumiDataItemTable, DataItemRow>,
          ),
          DataItemRow,
          PrefetchHooks Function()
        > {
  $$BangumiDataItemTableTableManager(
    _$BtDatabase db,
    $BangumiDataItemTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BangumiDataItemTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BangumiDataItemTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BangumiDataItemTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> titleTranslate = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> lang = const Value.absent(),
                Value<String?> officialSite = const Value.absent(),
                Value<String?> begin = const Value.absent(),
                Value<String?> broadcast = const Value.absent(),
                Value<String?> end = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> sites = const Value.absent(),
              }) => BangumiDataItemCompanion(
                id: id,
                title: title,
                titleTranslate: titleTranslate,
                type: type,
                lang: lang,
                officialSite: officialSite,
                begin: begin,
                broadcast: broadcast,
                end: end,
                comment: comment,
                sites: sites,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<String?> titleTranslate = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> lang = const Value.absent(),
                Value<String?> officialSite = const Value.absent(),
                Value<String?> begin = const Value.absent(),
                Value<String?> broadcast = const Value.absent(),
                Value<String?> end = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> sites = const Value.absent(),
              }) => BangumiDataItemCompanion.insert(
                id: id,
                title: title,
                titleTranslate: titleTranslate,
                type: type,
                lang: lang,
                officialSite: officialSite,
                begin: begin,
                broadcast: broadcast,
                end: end,
                comment: comment,
                sites: sites,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BangumiDataItemTable, DataItemRow>(table),
                  BaseReferences<
                    _$BtDatabase,
                    $BangumiDataItemTable,
                    DataItemRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BangumiDataItemTableProcessedTableManager =
    ProcessedTableManager<
      _$BtDatabase,
      $BangumiDataItemTable,
      DataItemRow,
      $$BangumiDataItemTableFilterComposer,
      $$BangumiDataItemTableOrderingComposer,
      $$BangumiDataItemTableAnnotationComposer,
      $$BangumiDataItemTableCreateCompanionBuilder,
      $$BangumiDataItemTableUpdateCompanionBuilder,
      (
        DataItemRow,
        BaseReferences<_$BtDatabase, $BangumiDataItemTable, DataItemRow>,
      ),
      DataItemRow,
      PrefetchHooks Function()
    >;

class $BtDatabaseManager {
  final _$BtDatabase _db;
  $BtDatabaseManager(this._db);
  $$AppBmfTableTableManager get appBmf =>
      $$AppBmfTableTableManager(_db, _db.appBmf);
  $$AppRssTableTableManager get appRss =>
      $$AppRssTableTableManager(_db, _db.appRss);
  $$AppConfigTableTableManager get appConfig =>
      $$AppConfigTableTableManager(_db, _db.appConfig);
  $$AppPlaybackTableTableManager get appPlayback =>
      $$AppPlaybackTableTableManager(_db, _db.appPlayback);
  $$BangumiUserTableTableManager get bangumiUser =>
      $$BangumiUserTableTableManager(_db, _db.bangumiUser);
  $$BangumiCollectionTableTableManager get bangumiCollection =>
      $$BangumiCollectionTableTableManager(_db, _db.bangumiCollection);
  $$BangumiDataSiteTableTableManager get bangumiDataSite =>
      $$BangumiDataSiteTableTableManager(_db, _db.bangumiDataSite);
  $$BangumiDataItemTableTableManager get bangumiDataItem =>
      $$BangumiDataItemTableTableManager(_db, _db.bangumiDataItem);
}
