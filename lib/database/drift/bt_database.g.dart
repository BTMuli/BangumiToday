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
  @override
  List<GeneratedColumn> get $columns => [id, subject, title, download, airDate];
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
    if (data.containsKey('download')) {
      context.handle(
        _downloadMeta,
        download.isAcceptableOrUnknown(data['download']!, _downloadMeta),
      );
    }
    if (data.containsKey('airDate')) {
      context.handle(
        _airDateMeta,
        airDate.isAcceptableOrUnknown(data['airDate']!, _airDateMeta),
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
      download: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download'],
      ),
      airDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}airDate'],
      ),
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

  /// 下载目录
  final String? download;

  /// 放送日期
  final String? airDate;
  const BmfRow({
    required this.id,
    required this.subject,
    this.title,
    this.download,
    this.airDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject'] = Variable<int>(subject);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || download != null) {
      map['download'] = Variable<String>(download);
    }
    if (!nullToAbsent || airDate != null) {
      map['airDate'] = Variable<String>(airDate);
    }
    return map;
  }

  AppBmfCompanion toCompanion(bool nullToAbsent) {
    return AppBmfCompanion(
      id: Value(id),
      subject: Value(subject),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      download: download == null && nullToAbsent
          ? const Value.absent()
          : Value(download),
      airDate: airDate == null && nullToAbsent
          ? const Value.absent()
          : Value(airDate),
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
      download: serializer.fromJson<String?>(json['download']),
      airDate: serializer.fromJson<String?>(json['airDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subject': serializer.toJson<int>(subject),
      'title': serializer.toJson<String?>(title),
      'download': serializer.toJson<String?>(download),
      'airDate': serializer.toJson<String?>(airDate),
    };
  }

  BmfRow copyWith({
    int? id,
    int? subject,
    Value<String?> title = const Value.absent(),
    Value<String?> download = const Value.absent(),
    Value<String?> airDate = const Value.absent(),
  }) => BmfRow(
    id: id ?? this.id,
    subject: subject ?? this.subject,
    title: title.present ? title.value : this.title,
    download: download.present ? download.value : this.download,
    airDate: airDate.present ? airDate.value : this.airDate,
  );
  BmfRow copyWithCompanion(AppBmfCompanion data) {
    return BmfRow(
      id: data.id.present ? data.id.value : this.id,
      subject: data.subject.present ? data.subject.value : this.subject,
      title: data.title.present ? data.title.value : this.title,
      download: data.download.present ? data.download.value : this.download,
      airDate: data.airDate.present ? data.airDate.value : this.airDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BmfRow(')
          ..write('id: $id, ')
          ..write('subject: $subject, ')
          ..write('title: $title, ')
          ..write('download: $download, ')
          ..write('airDate: $airDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, subject, title, download, airDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BmfRow &&
          other.id == this.id &&
          other.subject == this.subject &&
          other.title == this.title &&
          other.download == this.download &&
          other.airDate == this.airDate);
}

class AppBmfCompanion extends UpdateCompanion<BmfRow> {
  final Value<int> id;
  final Value<int> subject;
  final Value<String?> title;
  final Value<String?> download;
  final Value<String?> airDate;
  const AppBmfCompanion({
    this.id = const Value.absent(),
    this.subject = const Value.absent(),
    this.title = const Value.absent(),
    this.download = const Value.absent(),
    this.airDate = const Value.absent(),
  });
  AppBmfCompanion.insert({
    this.id = const Value.absent(),
    required int subject,
    this.title = const Value.absent(),
    this.download = const Value.absent(),
    this.airDate = const Value.absent(),
  }) : subject = Value(subject);
  static Insertable<BmfRow> custom({
    Expression<int>? id,
    Expression<int>? subject,
    Expression<String>? title,
    Expression<String>? download,
    Expression<String>? airDate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subject != null) 'subject': subject,
      if (title != null) 'title': title,
      if (download != null) 'download': download,
      if (airDate != null) 'airDate': airDate,
    });
  }

  AppBmfCompanion copyWith({
    Value<int>? id,
    Value<int>? subject,
    Value<String?>? title,
    Value<String?>? download,
    Value<String?>? airDate,
  }) {
    return AppBmfCompanion(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      title: title ?? this.title,
      download: download ?? this.download,
      airDate: airDate ?? this.airDate,
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
    if (download.present) {
      map['download'] = Variable<String>(download.value);
    }
    if (airDate.present) {
      map['airDate'] = Variable<String>(airDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppBmfCompanion(')
          ..write('id: $id, ')
          ..write('subject: $subject, ')
          ..write('title: $title, ')
          ..write('download: $download, ')
          ..write('airDate: $airDate')
          ..write(')'))
        .toString();
  }
}

class $AppSubscriptionTable extends AppSubscription
    with TableInfo<$AppSubscriptionTable, SubscriptionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSubscriptionTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _bmfIdMeta = const VerificationMeta('bmfId');
  @override
  late final GeneratedColumn<int> bmfId = GeneratedColumn<int>(
    'bmfId',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES AppBmf (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('generic'),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _feedKeyMeta = const VerificationMeta(
    'feedKey',
  );
  @override
  late final GeneratedColumn<String> feedKey = GeneratedColumn<String>(
    'feedKey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceConfigMeta = const VerificationMeta(
    'sourceConfig',
  );
  @override
  late final GeneratedColumn<String> sourceConfig = GeneratedColumn<String>(
    'sourceConfig',
    aliasedName,
    false,
    check: () => const CustomExpression(
      "json_valid(sourceConfig) "
      "AND json_type(sourceConfig) = 'object'",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{"version":1}'),
  );
  static const VerificationMeta _autoUpdateMeta = const VerificationMeta(
    'autoUpdate',
  );
  @override
  late final GeneratedColumn<int> autoUpdate = GeneratedColumn<int>(
    'autoUpdate',
    aliasedName,
    false,
    check: () => const CustomExpression('autoUpdate IN (0, 1)'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    check: () => const CustomExpression("status IN ('active', 'needsReview')"),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _pendingItemsMeta = const VerificationMeta(
    'pendingItems',
  );
  @override
  late final GeneratedColumn<String> pendingItems = GeneratedColumn<String>(
    'pendingItems',
    aliasedName,
    false,
    check: () => const CustomExpression(
      "json_valid(pendingItems) "
      "AND json_type(pendingItems) = 'array'",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _knownItemsMeta = const VerificationMeta(
    'knownItems',
  );
  @override
  late final GeneratedColumn<String> knownItems = GeneratedColumn<String>(
    'knownItems',
    aliasedName,
    false,
    check: () => const CustomExpression(
      "json_valid(knownItems) "
      "AND json_type(knownItems) = 'array'",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _hasBaselineMeta = const VerificationMeta(
    'hasBaseline',
  );
  @override
  late final GeneratedColumn<int> hasBaseline = GeneratedColumn<int>(
    'hasBaseline',
    aliasedName,
    false,
    check: () => const CustomExpression('hasBaseline IN (0, 1)'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _itemKeyVersionMeta = const VerificationMeta(
    'itemKeyVersion',
  );
  @override
  late final GeneratedColumn<int> itemKeyVersion = GeneratedColumn<int>(
    'itemKeyVersion',
    aliasedName,
    false,
    check: () => const CustomExpression('itemKeyVersion > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bmfId,
    provider,
    url,
    feedKey,
    sourceConfig,
    autoUpdate,
    status,
    pendingItems,
    knownItems,
    hasBaseline,
    itemKeyVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'AppSubscription';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubscriptionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bmfId')) {
      context.handle(
        _bmfIdMeta,
        bmfId.isAcceptableOrUnknown(data['bmfId']!, _bmfIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bmfIdMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('feedKey')) {
      context.handle(
        _feedKeyMeta,
        feedKey.isAcceptableOrUnknown(data['feedKey']!, _feedKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_feedKeyMeta);
    }
    if (data.containsKey('sourceConfig')) {
      context.handle(
        _sourceConfigMeta,
        sourceConfig.isAcceptableOrUnknown(
          data['sourceConfig']!,
          _sourceConfigMeta,
        ),
      );
    }
    if (data.containsKey('autoUpdate')) {
      context.handle(
        _autoUpdateMeta,
        autoUpdate.isAcceptableOrUnknown(data['autoUpdate']!, _autoUpdateMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
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
    if (data.containsKey('knownItems')) {
      context.handle(
        _knownItemsMeta,
        knownItems.isAcceptableOrUnknown(data['knownItems']!, _knownItemsMeta),
      );
    }
    if (data.containsKey('hasBaseline')) {
      context.handle(
        _hasBaselineMeta,
        hasBaseline.isAcceptableOrUnknown(
          data['hasBaseline']!,
          _hasBaselineMeta,
        ),
      );
    }
    if (data.containsKey('itemKeyVersion')) {
      context.handle(
        _itemKeyVersionMeta,
        itemKeyVersion.isAcceptableOrUnknown(
          data['itemKeyVersion']!,
          _itemKeyVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {bmfId, feedKey},
  ];
  @override
  SubscriptionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubscriptionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bmfId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bmfId'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      feedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feedKey'],
      )!,
      sourceConfig: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sourceConfig'],
      )!,
      autoUpdate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}autoUpdate'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      pendingItems: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pendingItems'],
      )!,
      knownItems: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}knownItems'],
      )!,
      hasBaseline: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hasBaseline'],
      )!,
      itemKeyVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}itemKeyVersion'],
      )!,
    );
  }

  @override
  $AppSubscriptionTable createAlias(String alias) {
    return $AppSubscriptionTable(attachedDatabase, alias);
  }
}

class SubscriptionRow extends DataClass implements Insertable<SubscriptionRow> {
  final int id;
  final int bmfId;
  final String provider;
  final String url;
  final String feedKey;
  final String sourceConfig;
  final int autoUpdate;
  final String status;
  final String pendingItems;
  final String knownItems;
  final int hasBaseline;
  final int itemKeyVersion;
  const SubscriptionRow({
    required this.id,
    required this.bmfId,
    required this.provider,
    required this.url,
    required this.feedKey,
    required this.sourceConfig,
    required this.autoUpdate,
    required this.status,
    required this.pendingItems,
    required this.knownItems,
    required this.hasBaseline,
    required this.itemKeyVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bmfId'] = Variable<int>(bmfId);
    map['provider'] = Variable<String>(provider);
    map['url'] = Variable<String>(url);
    map['feedKey'] = Variable<String>(feedKey);
    map['sourceConfig'] = Variable<String>(sourceConfig);
    map['autoUpdate'] = Variable<int>(autoUpdate);
    map['status'] = Variable<String>(status);
    map['pendingItems'] = Variable<String>(pendingItems);
    map['knownItems'] = Variable<String>(knownItems);
    map['hasBaseline'] = Variable<int>(hasBaseline);
    map['itemKeyVersion'] = Variable<int>(itemKeyVersion);
    return map;
  }

  AppSubscriptionCompanion toCompanion(bool nullToAbsent) {
    return AppSubscriptionCompanion(
      id: Value(id),
      bmfId: Value(bmfId),
      provider: Value(provider),
      url: Value(url),
      feedKey: Value(feedKey),
      sourceConfig: Value(sourceConfig),
      autoUpdate: Value(autoUpdate),
      status: Value(status),
      pendingItems: Value(pendingItems),
      knownItems: Value(knownItems),
      hasBaseline: Value(hasBaseline),
      itemKeyVersion: Value(itemKeyVersion),
    );
  }

  factory SubscriptionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubscriptionRow(
      id: serializer.fromJson<int>(json['id']),
      bmfId: serializer.fromJson<int>(json['bmfId']),
      provider: serializer.fromJson<String>(json['provider']),
      url: serializer.fromJson<String>(json['url']),
      feedKey: serializer.fromJson<String>(json['feedKey']),
      sourceConfig: serializer.fromJson<String>(json['sourceConfig']),
      autoUpdate: serializer.fromJson<int>(json['autoUpdate']),
      status: serializer.fromJson<String>(json['status']),
      pendingItems: serializer.fromJson<String>(json['pendingItems']),
      knownItems: serializer.fromJson<String>(json['knownItems']),
      hasBaseline: serializer.fromJson<int>(json['hasBaseline']),
      itemKeyVersion: serializer.fromJson<int>(json['itemKeyVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bmfId': serializer.toJson<int>(bmfId),
      'provider': serializer.toJson<String>(provider),
      'url': serializer.toJson<String>(url),
      'feedKey': serializer.toJson<String>(feedKey),
      'sourceConfig': serializer.toJson<String>(sourceConfig),
      'autoUpdate': serializer.toJson<int>(autoUpdate),
      'status': serializer.toJson<String>(status),
      'pendingItems': serializer.toJson<String>(pendingItems),
      'knownItems': serializer.toJson<String>(knownItems),
      'hasBaseline': serializer.toJson<int>(hasBaseline),
      'itemKeyVersion': serializer.toJson<int>(itemKeyVersion),
    };
  }

  SubscriptionRow copyWith({
    int? id,
    int? bmfId,
    String? provider,
    String? url,
    String? feedKey,
    String? sourceConfig,
    int? autoUpdate,
    String? status,
    String? pendingItems,
    String? knownItems,
    int? hasBaseline,
    int? itemKeyVersion,
  }) => SubscriptionRow(
    id: id ?? this.id,
    bmfId: bmfId ?? this.bmfId,
    provider: provider ?? this.provider,
    url: url ?? this.url,
    feedKey: feedKey ?? this.feedKey,
    sourceConfig: sourceConfig ?? this.sourceConfig,
    autoUpdate: autoUpdate ?? this.autoUpdate,
    status: status ?? this.status,
    pendingItems: pendingItems ?? this.pendingItems,
    knownItems: knownItems ?? this.knownItems,
    hasBaseline: hasBaseline ?? this.hasBaseline,
    itemKeyVersion: itemKeyVersion ?? this.itemKeyVersion,
  );
  SubscriptionRow copyWithCompanion(AppSubscriptionCompanion data) {
    return SubscriptionRow(
      id: data.id.present ? data.id.value : this.id,
      bmfId: data.bmfId.present ? data.bmfId.value : this.bmfId,
      provider: data.provider.present ? data.provider.value : this.provider,
      url: data.url.present ? data.url.value : this.url,
      feedKey: data.feedKey.present ? data.feedKey.value : this.feedKey,
      sourceConfig: data.sourceConfig.present
          ? data.sourceConfig.value
          : this.sourceConfig,
      autoUpdate: data.autoUpdate.present
          ? data.autoUpdate.value
          : this.autoUpdate,
      status: data.status.present ? data.status.value : this.status,
      pendingItems: data.pendingItems.present
          ? data.pendingItems.value
          : this.pendingItems,
      knownItems: data.knownItems.present
          ? data.knownItems.value
          : this.knownItems,
      hasBaseline: data.hasBaseline.present
          ? data.hasBaseline.value
          : this.hasBaseline,
      itemKeyVersion: data.itemKeyVersion.present
          ? data.itemKeyVersion.value
          : this.itemKeyVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubscriptionRow(')
          ..write('id: $id, ')
          ..write('bmfId: $bmfId, ')
          ..write('provider: $provider, ')
          ..write('url: $url, ')
          ..write('feedKey: $feedKey, ')
          ..write('sourceConfig: $sourceConfig, ')
          ..write('autoUpdate: $autoUpdate, ')
          ..write('status: $status, ')
          ..write('pendingItems: $pendingItems, ')
          ..write('knownItems: $knownItems, ')
          ..write('hasBaseline: $hasBaseline, ')
          ..write('itemKeyVersion: $itemKeyVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bmfId,
    provider,
    url,
    feedKey,
    sourceConfig,
    autoUpdate,
    status,
    pendingItems,
    knownItems,
    hasBaseline,
    itemKeyVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubscriptionRow &&
          other.id == this.id &&
          other.bmfId == this.bmfId &&
          other.provider == this.provider &&
          other.url == this.url &&
          other.feedKey == this.feedKey &&
          other.sourceConfig == this.sourceConfig &&
          other.autoUpdate == this.autoUpdate &&
          other.status == this.status &&
          other.pendingItems == this.pendingItems &&
          other.knownItems == this.knownItems &&
          other.hasBaseline == this.hasBaseline &&
          other.itemKeyVersion == this.itemKeyVersion);
}

class AppSubscriptionCompanion extends UpdateCompanion<SubscriptionRow> {
  final Value<int> id;
  final Value<int> bmfId;
  final Value<String> provider;
  final Value<String> url;
  final Value<String> feedKey;
  final Value<String> sourceConfig;
  final Value<int> autoUpdate;
  final Value<String> status;
  final Value<String> pendingItems;
  final Value<String> knownItems;
  final Value<int> hasBaseline;
  final Value<int> itemKeyVersion;
  const AppSubscriptionCompanion({
    this.id = const Value.absent(),
    this.bmfId = const Value.absent(),
    this.provider = const Value.absent(),
    this.url = const Value.absent(),
    this.feedKey = const Value.absent(),
    this.sourceConfig = const Value.absent(),
    this.autoUpdate = const Value.absent(),
    this.status = const Value.absent(),
    this.pendingItems = const Value.absent(),
    this.knownItems = const Value.absent(),
    this.hasBaseline = const Value.absent(),
    this.itemKeyVersion = const Value.absent(),
  });
  AppSubscriptionCompanion.insert({
    this.id = const Value.absent(),
    required int bmfId,
    this.provider = const Value.absent(),
    required String url,
    required String feedKey,
    this.sourceConfig = const Value.absent(),
    this.autoUpdate = const Value.absent(),
    this.status = const Value.absent(),
    this.pendingItems = const Value.absent(),
    this.knownItems = const Value.absent(),
    this.hasBaseline = const Value.absent(),
    this.itemKeyVersion = const Value.absent(),
  }) : bmfId = Value(bmfId),
       url = Value(url),
       feedKey = Value(feedKey);
  static Insertable<SubscriptionRow> custom({
    Expression<int>? id,
    Expression<int>? bmfId,
    Expression<String>? provider,
    Expression<String>? url,
    Expression<String>? feedKey,
    Expression<String>? sourceConfig,
    Expression<int>? autoUpdate,
    Expression<String>? status,
    Expression<String>? pendingItems,
    Expression<String>? knownItems,
    Expression<int>? hasBaseline,
    Expression<int>? itemKeyVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bmfId != null) 'bmfId': bmfId,
      if (provider != null) 'provider': provider,
      if (url != null) 'url': url,
      if (feedKey != null) 'feedKey': feedKey,
      if (sourceConfig != null) 'sourceConfig': sourceConfig,
      if (autoUpdate != null) 'autoUpdate': autoUpdate,
      if (status != null) 'status': status,
      if (pendingItems != null) 'pendingItems': pendingItems,
      if (knownItems != null) 'knownItems': knownItems,
      if (hasBaseline != null) 'hasBaseline': hasBaseline,
      if (itemKeyVersion != null) 'itemKeyVersion': itemKeyVersion,
    });
  }

  AppSubscriptionCompanion copyWith({
    Value<int>? id,
    Value<int>? bmfId,
    Value<String>? provider,
    Value<String>? url,
    Value<String>? feedKey,
    Value<String>? sourceConfig,
    Value<int>? autoUpdate,
    Value<String>? status,
    Value<String>? pendingItems,
    Value<String>? knownItems,
    Value<int>? hasBaseline,
    Value<int>? itemKeyVersion,
  }) {
    return AppSubscriptionCompanion(
      id: id ?? this.id,
      bmfId: bmfId ?? this.bmfId,
      provider: provider ?? this.provider,
      url: url ?? this.url,
      feedKey: feedKey ?? this.feedKey,
      sourceConfig: sourceConfig ?? this.sourceConfig,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      status: status ?? this.status,
      pendingItems: pendingItems ?? this.pendingItems,
      knownItems: knownItems ?? this.knownItems,
      hasBaseline: hasBaseline ?? this.hasBaseline,
      itemKeyVersion: itemKeyVersion ?? this.itemKeyVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bmfId.present) {
      map['bmfId'] = Variable<int>(bmfId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (feedKey.present) {
      map['feedKey'] = Variable<String>(feedKey.value);
    }
    if (sourceConfig.present) {
      map['sourceConfig'] = Variable<String>(sourceConfig.value);
    }
    if (autoUpdate.present) {
      map['autoUpdate'] = Variable<int>(autoUpdate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (pendingItems.present) {
      map['pendingItems'] = Variable<String>(pendingItems.value);
    }
    if (knownItems.present) {
      map['knownItems'] = Variable<String>(knownItems.value);
    }
    if (hasBaseline.present) {
      map['hasBaseline'] = Variable<int>(hasBaseline.value);
    }
    if (itemKeyVersion.present) {
      map['itemKeyVersion'] = Variable<int>(itemKeyVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSubscriptionCompanion(')
          ..write('id: $id, ')
          ..write('bmfId: $bmfId, ')
          ..write('provider: $provider, ')
          ..write('url: $url, ')
          ..write('feedKey: $feedKey, ')
          ..write('sourceConfig: $sourceConfig, ')
          ..write('autoUpdate: $autoUpdate, ')
          ..write('status: $status, ')
          ..write('pendingItems: $pendingItems, ')
          ..write('knownItems: $knownItems, ')
          ..write('hasBaseline: $hasBaseline, ')
          ..write('itemKeyVersion: $itemKeyVersion')
          ..write(')'))
        .toString();
  }
}

class $AppRssCacheTable extends AppRssCache
    with TableInfo<$AppRssCacheTable, RssCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppRssCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _feedKeyMeta = const VerificationMeta(
    'feedKey',
  );
  @override
  late final GeneratedColumn<String> feedKey = GeneratedColumn<String>(
    'feedKey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestUrlMeta = const VerificationMeta(
    'requestUrl',
  );
  @override
  late final GeneratedColumn<String> requestUrl = GeneratedColumn<String>(
    'requestUrl',
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
  static const VerificationMeta _ttlMinutesMeta = const VerificationMeta(
    'ttlMinutes',
  );
  @override
  late final GeneratedColumn<int> ttlMinutes = GeneratedColumn<int>(
    'ttlMinutes',
    aliasedName,
    false,
    check: () => const CustomExpression('ttlMinutes >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSuccessAtMeta = const VerificationMeta(
    'lastSuccessAt',
  );
  @override
  late final GeneratedColumn<int> lastSuccessAt = GeneratedColumn<int>(
    'lastSuccessAt',
    aliasedName,
    false,
    check: () => const CustomExpression('lastSuccessAt >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<int> lastAttemptAt = GeneratedColumn<int>(
    'lastAttemptAt',
    aliasedName,
    false,
    check: () => const CustomExpression('lastAttemptAt >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastFailedAtMeta = const VerificationMeta(
    'lastFailedAt',
  );
  @override
  late final GeneratedColumn<int> lastFailedAt = GeneratedColumn<int>(
    'lastFailedAt',
    aliasedName,
    false,
    check: () => const CustomExpression('lastFailedAt >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cacheVersionMeta = const VerificationMeta(
    'cacheVersion',
  );
  @override
  late final GeneratedColumn<int> cacheVersion = GeneratedColumn<int>(
    'cacheVersion',
    aliasedName,
    false,
    check: () => const CustomExpression('cacheVersion > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    feedKey,
    requestUrl,
    data,
    ttlMinutes,
    lastSuccessAt,
    lastAttemptAt,
    lastFailedAt,
    cacheVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'AppRssCache';
  @override
  VerificationContext validateIntegrity(
    Insertable<RssCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('feedKey')) {
      context.handle(
        _feedKeyMeta,
        feedKey.isAcceptableOrUnknown(data['feedKey']!, _feedKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_feedKeyMeta);
    }
    if (data.containsKey('requestUrl')) {
      context.handle(
        _requestUrlMeta,
        requestUrl.isAcceptableOrUnknown(data['requestUrl']!, _requestUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_requestUrlMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    }
    if (data.containsKey('ttlMinutes')) {
      context.handle(
        _ttlMinutesMeta,
        ttlMinutes.isAcceptableOrUnknown(data['ttlMinutes']!, _ttlMinutesMeta),
      );
    }
    if (data.containsKey('lastSuccessAt')) {
      context.handle(
        _lastSuccessAtMeta,
        lastSuccessAt.isAcceptableOrUnknown(
          data['lastSuccessAt']!,
          _lastSuccessAtMeta,
        ),
      );
    }
    if (data.containsKey('lastAttemptAt')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['lastAttemptAt']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('lastFailedAt')) {
      context.handle(
        _lastFailedAtMeta,
        lastFailedAt.isAcceptableOrUnknown(
          data['lastFailedAt']!,
          _lastFailedAtMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {feedKey};
  @override
  RssCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RssCacheRow(
      feedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feedKey'],
      )!,
      requestUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}requestUrl'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      ),
      ttlMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ttlMinutes'],
      )!,
      lastSuccessAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lastSuccessAt'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lastAttemptAt'],
      )!,
      lastFailedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lastFailedAt'],
      )!,
      cacheVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cacheVersion'],
      )!,
    );
  }

  @override
  $AppRssCacheTable createAlias(String alias) {
    return $AppRssCacheTable(attachedDatabase, alias);
  }
}

class RssCacheRow extends DataClass implements Insertable<RssCacheRow> {
  final String feedKey;
  final String requestUrl;
  final String? data;
  final int ttlMinutes;
  final int lastSuccessAt;
  final int lastAttemptAt;
  final int lastFailedAt;
  final int cacheVersion;
  const RssCacheRow({
    required this.feedKey,
    required this.requestUrl,
    this.data,
    required this.ttlMinutes,
    required this.lastSuccessAt,
    required this.lastAttemptAt,
    required this.lastFailedAt,
    required this.cacheVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['feedKey'] = Variable<String>(feedKey);
    map['requestUrl'] = Variable<String>(requestUrl);
    if (!nullToAbsent || data != null) {
      map['data'] = Variable<String>(data);
    }
    map['ttlMinutes'] = Variable<int>(ttlMinutes);
    map['lastSuccessAt'] = Variable<int>(lastSuccessAt);
    map['lastAttemptAt'] = Variable<int>(lastAttemptAt);
    map['lastFailedAt'] = Variable<int>(lastFailedAt);
    map['cacheVersion'] = Variable<int>(cacheVersion);
    return map;
  }

  AppRssCacheCompanion toCompanion(bool nullToAbsent) {
    return AppRssCacheCompanion(
      feedKey: Value(feedKey),
      requestUrl: Value(requestUrl),
      data: data == null && nullToAbsent ? const Value.absent() : Value(data),
      ttlMinutes: Value(ttlMinutes),
      lastSuccessAt: Value(lastSuccessAt),
      lastAttemptAt: Value(lastAttemptAt),
      lastFailedAt: Value(lastFailedAt),
      cacheVersion: Value(cacheVersion),
    );
  }

  factory RssCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RssCacheRow(
      feedKey: serializer.fromJson<String>(json['feedKey']),
      requestUrl: serializer.fromJson<String>(json['requestUrl']),
      data: serializer.fromJson<String?>(json['data']),
      ttlMinutes: serializer.fromJson<int>(json['ttlMinutes']),
      lastSuccessAt: serializer.fromJson<int>(json['lastSuccessAt']),
      lastAttemptAt: serializer.fromJson<int>(json['lastAttemptAt']),
      lastFailedAt: serializer.fromJson<int>(json['lastFailedAt']),
      cacheVersion: serializer.fromJson<int>(json['cacheVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'feedKey': serializer.toJson<String>(feedKey),
      'requestUrl': serializer.toJson<String>(requestUrl),
      'data': serializer.toJson<String?>(data),
      'ttlMinutes': serializer.toJson<int>(ttlMinutes),
      'lastSuccessAt': serializer.toJson<int>(lastSuccessAt),
      'lastAttemptAt': serializer.toJson<int>(lastAttemptAt),
      'lastFailedAt': serializer.toJson<int>(lastFailedAt),
      'cacheVersion': serializer.toJson<int>(cacheVersion),
    };
  }

  RssCacheRow copyWith({
    String? feedKey,
    String? requestUrl,
    Value<String?> data = const Value.absent(),
    int? ttlMinutes,
    int? lastSuccessAt,
    int? lastAttemptAt,
    int? lastFailedAt,
    int? cacheVersion,
  }) => RssCacheRow(
    feedKey: feedKey ?? this.feedKey,
    requestUrl: requestUrl ?? this.requestUrl,
    data: data.present ? data.value : this.data,
    ttlMinutes: ttlMinutes ?? this.ttlMinutes,
    lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    lastFailedAt: lastFailedAt ?? this.lastFailedAt,
    cacheVersion: cacheVersion ?? this.cacheVersion,
  );
  RssCacheRow copyWithCompanion(AppRssCacheCompanion data) {
    return RssCacheRow(
      feedKey: data.feedKey.present ? data.feedKey.value : this.feedKey,
      requestUrl: data.requestUrl.present
          ? data.requestUrl.value
          : this.requestUrl,
      data: data.data.present ? data.data.value : this.data,
      ttlMinutes: data.ttlMinutes.present
          ? data.ttlMinutes.value
          : this.ttlMinutes,
      lastSuccessAt: data.lastSuccessAt.present
          ? data.lastSuccessAt.value
          : this.lastSuccessAt,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      lastFailedAt: data.lastFailedAt.present
          ? data.lastFailedAt.value
          : this.lastFailedAt,
      cacheVersion: data.cacheVersion.present
          ? data.cacheVersion.value
          : this.cacheVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RssCacheRow(')
          ..write('feedKey: $feedKey, ')
          ..write('requestUrl: $requestUrl, ')
          ..write('data: $data, ')
          ..write('ttlMinutes: $ttlMinutes, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('lastFailedAt: $lastFailedAt, ')
          ..write('cacheVersion: $cacheVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    feedKey,
    requestUrl,
    data,
    ttlMinutes,
    lastSuccessAt,
    lastAttemptAt,
    lastFailedAt,
    cacheVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RssCacheRow &&
          other.feedKey == this.feedKey &&
          other.requestUrl == this.requestUrl &&
          other.data == this.data &&
          other.ttlMinutes == this.ttlMinutes &&
          other.lastSuccessAt == this.lastSuccessAt &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.lastFailedAt == this.lastFailedAt &&
          other.cacheVersion == this.cacheVersion);
}

class AppRssCacheCompanion extends UpdateCompanion<RssCacheRow> {
  final Value<String> feedKey;
  final Value<String> requestUrl;
  final Value<String?> data;
  final Value<int> ttlMinutes;
  final Value<int> lastSuccessAt;
  final Value<int> lastAttemptAt;
  final Value<int> lastFailedAt;
  final Value<int> cacheVersion;
  final Value<int> rowid;
  const AppRssCacheCompanion({
    this.feedKey = const Value.absent(),
    this.requestUrl = const Value.absent(),
    this.data = const Value.absent(),
    this.ttlMinutes = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.lastFailedAt = const Value.absent(),
    this.cacheVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppRssCacheCompanion.insert({
    required String feedKey,
    required String requestUrl,
    this.data = const Value.absent(),
    this.ttlMinutes = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.lastFailedAt = const Value.absent(),
    this.cacheVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : feedKey = Value(feedKey),
       requestUrl = Value(requestUrl);
  static Insertable<RssCacheRow> custom({
    Expression<String>? feedKey,
    Expression<String>? requestUrl,
    Expression<String>? data,
    Expression<int>? ttlMinutes,
    Expression<int>? lastSuccessAt,
    Expression<int>? lastAttemptAt,
    Expression<int>? lastFailedAt,
    Expression<int>? cacheVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (feedKey != null) 'feedKey': feedKey,
      if (requestUrl != null) 'requestUrl': requestUrl,
      if (data != null) 'data': data,
      if (ttlMinutes != null) 'ttlMinutes': ttlMinutes,
      if (lastSuccessAt != null) 'lastSuccessAt': lastSuccessAt,
      if (lastAttemptAt != null) 'lastAttemptAt': lastAttemptAt,
      if (lastFailedAt != null) 'lastFailedAt': lastFailedAt,
      if (cacheVersion != null) 'cacheVersion': cacheVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppRssCacheCompanion copyWith({
    Value<String>? feedKey,
    Value<String>? requestUrl,
    Value<String?>? data,
    Value<int>? ttlMinutes,
    Value<int>? lastSuccessAt,
    Value<int>? lastAttemptAt,
    Value<int>? lastFailedAt,
    Value<int>? cacheVersion,
    Value<int>? rowid,
  }) {
    return AppRssCacheCompanion(
      feedKey: feedKey ?? this.feedKey,
      requestUrl: requestUrl ?? this.requestUrl,
      data: data ?? this.data,
      ttlMinutes: ttlMinutes ?? this.ttlMinutes,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastFailedAt: lastFailedAt ?? this.lastFailedAt,
      cacheVersion: cacheVersion ?? this.cacheVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (feedKey.present) {
      map['feedKey'] = Variable<String>(feedKey.value);
    }
    if (requestUrl.present) {
      map['requestUrl'] = Variable<String>(requestUrl.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (ttlMinutes.present) {
      map['ttlMinutes'] = Variable<int>(ttlMinutes.value);
    }
    if (lastSuccessAt.present) {
      map['lastSuccessAt'] = Variable<int>(lastSuccessAt.value);
    }
    if (lastAttemptAt.present) {
      map['lastAttemptAt'] = Variable<int>(lastAttemptAt.value);
    }
    if (lastFailedAt.present) {
      map['lastFailedAt'] = Variable<int>(lastFailedAt.value);
    }
    if (cacheVersion.present) {
      map['cacheVersion'] = Variable<int>(cacheVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppRssCacheCompanion(')
          ..write('feedKey: $feedKey, ')
          ..write('requestUrl: $requestUrl, ')
          ..write('data: $data, ')
          ..write('ttlMinutes: $ttlMinutes, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('lastFailedAt: $lastFailedAt, ')
          ..write('cacheVersion: $cacheVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppMigrationRecoveryTable extends AppMigrationRecovery
    with TableInfo<$AppMigrationRecoveryTable, MigrationRecoveryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMigrationRecoveryTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _migrationVersionMeta = const VerificationMeta(
    'migrationVersion',
  );
  @override
  late final GeneratedColumn<int> migrationVersion = GeneratedColumn<int>(
    'migrationVersion',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legacyKeyMeta = const VerificationMeta(
    'legacyKey',
  );
  @override
  late final GeneratedColumn<String> legacyKey = GeneratedColumn<String>(
    'legacyKey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    check: () => const CustomExpression(
      "json_valid(payload) "
      "AND json_type(payload) = 'object'",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _candidateBmfIdsMeta = const VerificationMeta(
    'candidateBmfIds',
  );
  @override
  late final GeneratedColumn<String> candidateBmfIds = GeneratedColumn<String>(
    'candidateBmfIds',
    aliasedName,
    false,
    check: () => const CustomExpression(
      "json_valid(candidateBmfIds) "
      "AND json_type(candidateBmfIds) = 'array'",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'createdAt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<int> resolvedAt = GeneratedColumn<int>(
    'resolvedAt',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    migrationVersion,
    kind,
    legacyKey,
    payload,
    candidateBmfIds,
    createdAt,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'AppMigrationRecovery';
  @override
  VerificationContext validateIntegrity(
    Insertable<MigrationRecoveryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('migrationVersion')) {
      context.handle(
        _migrationVersionMeta,
        migrationVersion.isAcceptableOrUnknown(
          data['migrationVersion']!,
          _migrationVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_migrationVersionMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('legacyKey')) {
      context.handle(
        _legacyKeyMeta,
        legacyKey.isAcceptableOrUnknown(data['legacyKey']!, _legacyKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_legacyKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('candidateBmfIds')) {
      context.handle(
        _candidateBmfIdsMeta,
        candidateBmfIds.isAcceptableOrUnknown(
          data['candidateBmfIds']!,
          _candidateBmfIdsMeta,
        ),
      );
    }
    if (data.containsKey('createdAt')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['createdAt']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('resolvedAt')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolvedAt']!, _resolvedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {migrationVersion, kind, legacyKey},
  ];
  @override
  MigrationRecoveryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MigrationRecoveryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      migrationVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}migrationVersion'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      legacyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}legacyKey'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      candidateBmfIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}candidateBmfIds'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}createdAt'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolvedAt'],
      ),
    );
  }

  @override
  $AppMigrationRecoveryTable createAlias(String alias) {
    return $AppMigrationRecoveryTable(attachedDatabase, alias);
  }
}

class MigrationRecoveryRow extends DataClass
    implements Insertable<MigrationRecoveryRow> {
  final int id;
  final int migrationVersion;
  final String kind;
  final String legacyKey;
  final String payload;
  final String candidateBmfIds;
  final int createdAt;
  final int? resolvedAt;
  const MigrationRecoveryRow({
    required this.id,
    required this.migrationVersion,
    required this.kind,
    required this.legacyKey,
    required this.payload,
    required this.candidateBmfIds,
    required this.createdAt,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['migrationVersion'] = Variable<int>(migrationVersion);
    map['kind'] = Variable<String>(kind);
    map['legacyKey'] = Variable<String>(legacyKey);
    map['payload'] = Variable<String>(payload);
    map['candidateBmfIds'] = Variable<String>(candidateBmfIds);
    map['createdAt'] = Variable<int>(createdAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolvedAt'] = Variable<int>(resolvedAt);
    }
    return map;
  }

  AppMigrationRecoveryCompanion toCompanion(bool nullToAbsent) {
    return AppMigrationRecoveryCompanion(
      id: Value(id),
      migrationVersion: Value(migrationVersion),
      kind: Value(kind),
      legacyKey: Value(legacyKey),
      payload: Value(payload),
      candidateBmfIds: Value(candidateBmfIds),
      createdAt: Value(createdAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory MigrationRecoveryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MigrationRecoveryRow(
      id: serializer.fromJson<int>(json['id']),
      migrationVersion: serializer.fromJson<int>(json['migrationVersion']),
      kind: serializer.fromJson<String>(json['kind']),
      legacyKey: serializer.fromJson<String>(json['legacyKey']),
      payload: serializer.fromJson<String>(json['payload']),
      candidateBmfIds: serializer.fromJson<String>(json['candidateBmfIds']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      resolvedAt: serializer.fromJson<int?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'migrationVersion': serializer.toJson<int>(migrationVersion),
      'kind': serializer.toJson<String>(kind),
      'legacyKey': serializer.toJson<String>(legacyKey),
      'payload': serializer.toJson<String>(payload),
      'candidateBmfIds': serializer.toJson<String>(candidateBmfIds),
      'createdAt': serializer.toJson<int>(createdAt),
      'resolvedAt': serializer.toJson<int?>(resolvedAt),
    };
  }

  MigrationRecoveryRow copyWith({
    int? id,
    int? migrationVersion,
    String? kind,
    String? legacyKey,
    String? payload,
    String? candidateBmfIds,
    int? createdAt,
    Value<int?> resolvedAt = const Value.absent(),
  }) => MigrationRecoveryRow(
    id: id ?? this.id,
    migrationVersion: migrationVersion ?? this.migrationVersion,
    kind: kind ?? this.kind,
    legacyKey: legacyKey ?? this.legacyKey,
    payload: payload ?? this.payload,
    candidateBmfIds: candidateBmfIds ?? this.candidateBmfIds,
    createdAt: createdAt ?? this.createdAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  MigrationRecoveryRow copyWithCompanion(AppMigrationRecoveryCompanion data) {
    return MigrationRecoveryRow(
      id: data.id.present ? data.id.value : this.id,
      migrationVersion: data.migrationVersion.present
          ? data.migrationVersion.value
          : this.migrationVersion,
      kind: data.kind.present ? data.kind.value : this.kind,
      legacyKey: data.legacyKey.present ? data.legacyKey.value : this.legacyKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      candidateBmfIds: data.candidateBmfIds.present
          ? data.candidateBmfIds.value
          : this.candidateBmfIds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MigrationRecoveryRow(')
          ..write('id: $id, ')
          ..write('migrationVersion: $migrationVersion, ')
          ..write('kind: $kind, ')
          ..write('legacyKey: $legacyKey, ')
          ..write('payload: $payload, ')
          ..write('candidateBmfIds: $candidateBmfIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    migrationVersion,
    kind,
    legacyKey,
    payload,
    candidateBmfIds,
    createdAt,
    resolvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MigrationRecoveryRow &&
          other.id == this.id &&
          other.migrationVersion == this.migrationVersion &&
          other.kind == this.kind &&
          other.legacyKey == this.legacyKey &&
          other.payload == this.payload &&
          other.candidateBmfIds == this.candidateBmfIds &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt);
}

class AppMigrationRecoveryCompanion
    extends UpdateCompanion<MigrationRecoveryRow> {
  final Value<int> id;
  final Value<int> migrationVersion;
  final Value<String> kind;
  final Value<String> legacyKey;
  final Value<String> payload;
  final Value<String> candidateBmfIds;
  final Value<int> createdAt;
  final Value<int?> resolvedAt;
  const AppMigrationRecoveryCompanion({
    this.id = const Value.absent(),
    this.migrationVersion = const Value.absent(),
    this.kind = const Value.absent(),
    this.legacyKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.candidateBmfIds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
  });
  AppMigrationRecoveryCompanion.insert({
    this.id = const Value.absent(),
    required int migrationVersion,
    required String kind,
    required String legacyKey,
    required String payload,
    this.candidateBmfIds = const Value.absent(),
    required int createdAt,
    this.resolvedAt = const Value.absent(),
  }) : migrationVersion = Value(migrationVersion),
       kind = Value(kind),
       legacyKey = Value(legacyKey),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<MigrationRecoveryRow> custom({
    Expression<int>? id,
    Expression<int>? migrationVersion,
    Expression<String>? kind,
    Expression<String>? legacyKey,
    Expression<String>? payload,
    Expression<String>? candidateBmfIds,
    Expression<int>? createdAt,
    Expression<int>? resolvedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (migrationVersion != null) 'migrationVersion': migrationVersion,
      if (kind != null) 'kind': kind,
      if (legacyKey != null) 'legacyKey': legacyKey,
      if (payload != null) 'payload': payload,
      if (candidateBmfIds != null) 'candidateBmfIds': candidateBmfIds,
      if (createdAt != null) 'createdAt': createdAt,
      if (resolvedAt != null) 'resolvedAt': resolvedAt,
    });
  }

  AppMigrationRecoveryCompanion copyWith({
    Value<int>? id,
    Value<int>? migrationVersion,
    Value<String>? kind,
    Value<String>? legacyKey,
    Value<String>? payload,
    Value<String>? candidateBmfIds,
    Value<int>? createdAt,
    Value<int?>? resolvedAt,
  }) {
    return AppMigrationRecoveryCompanion(
      id: id ?? this.id,
      migrationVersion: migrationVersion ?? this.migrationVersion,
      kind: kind ?? this.kind,
      legacyKey: legacyKey ?? this.legacyKey,
      payload: payload ?? this.payload,
      candidateBmfIds: candidateBmfIds ?? this.candidateBmfIds,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (migrationVersion.present) {
      map['migrationVersion'] = Variable<int>(migrationVersion.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (legacyKey.present) {
      map['legacyKey'] = Variable<String>(legacyKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (candidateBmfIds.present) {
      map['candidateBmfIds'] = Variable<String>(candidateBmfIds.value);
    }
    if (createdAt.present) {
      map['createdAt'] = Variable<int>(createdAt.value);
    }
    if (resolvedAt.present) {
      map['resolvedAt'] = Variable<int>(resolvedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMigrationRecoveryCompanion(')
          ..write('id: $id, ')
          ..write('migrationVersion: $migrationVersion, ')
          ..write('kind: $kind, ')
          ..write('legacyKey: $legacyKey, ')
          ..write('payload: $payload, ')
          ..write('candidateBmfIds: $candidateBmfIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
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
  late final $AppSubscriptionTable appSubscription = $AppSubscriptionTable(
    this,
  );
  late final $AppRssCacheTable appRssCache = $AppRssCacheTable(this);
  late final $AppMigrationRecoveryTable appMigrationRecovery =
      $AppMigrationRecoveryTable(this);
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
  late final Index appSubscriptionFeedKey = Index(
    'AppSubscription_feedKey',
    'CREATE INDEX AppSubscription_feedKey ON AppSubscription (feedKey)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appBmf,
    appSubscription,
    appRssCache,
    appMigrationRecovery,
    appConfig,
    appPlayback,
    bangumiUser,
    bangumiCollection,
    bangumiDataSite,
    bangumiDataItem,
    appSubscriptionFeedKey,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'AppBmf',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('AppSubscription', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AppBmfTableCreateCompanionBuilder =
    AppBmfCompanion Function({
      Value<int> id,
      required int subject,
      Value<String?> title,
      Value<String?> download,
      Value<String?> airDate,
    });
typedef $$AppBmfTableUpdateCompanionBuilder =
    AppBmfCompanion Function({
      Value<int> id,
      Value<int> subject,
      Value<String?> title,
      Value<String?> download,
      Value<String?> airDate,
    });

final class $$AppBmfTableReferences
    extends BaseReferences<_$BtDatabase, $AppBmfTable, BmfRow> {
  $$AppBmfTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AppSubscriptionTable, List<SubscriptionRow>>
  _appSubscriptionRefsTable(_$BtDatabase db) => MultiTypedResultKey.fromTable(
    db.appSubscription,
    aliasName: 'AppBmf__id__AppSubscription__bmfId',
  );

  $$AppSubscriptionTableProcessedTableManager get appSubscriptionRefs {
    final manager = $$AppSubscriptionTableTableManager(
      $_db,
      $_db.appSubscription,
    ).filter((f) => f.bmfId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _appSubscriptionRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

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

  ColumnFilters<String> get download => $composableBuilder(
    column: $table.download,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> appSubscriptionRefs(
    Expression<bool> Function($$AppSubscriptionTableFilterComposer f) f,
  ) {
    final $$AppSubscriptionTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.appSubscription,
      getReferencedColumn: (t) => t.bmfId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppSubscriptionTableFilterComposer(
            $db: $db,
            $table: $db.appSubscription,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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

  ColumnOrderings<String> get download => $composableBuilder(
    column: $table.download,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get airDate => $composableBuilder(
    column: $table.airDate,
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

  GeneratedColumn<String> get download =>
      $composableBuilder(column: $table.download, builder: (column) => column);

  GeneratedColumn<String> get airDate =>
      $composableBuilder(column: $table.airDate, builder: (column) => column);

  Expression<T> appSubscriptionRefs<T extends Object>(
    Expression<T> Function($$AppSubscriptionTableAnnotationComposer a) f,
  ) {
    final $$AppSubscriptionTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.appSubscription,
      getReferencedColumn: (t) => t.bmfId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppSubscriptionTableAnnotationComposer(
            $db: $db,
            $table: $db.appSubscription,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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
          (BmfRow, $$AppBmfTableReferences),
          BmfRow,
          PrefetchHooks Function({bool appSubscriptionRefs})
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
                Value<String?> download = const Value.absent(),
                Value<String?> airDate = const Value.absent(),
              }) => AppBmfCompanion(
                id: id,
                subject: subject,
                title: title,
                download: download,
                airDate: airDate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subject,
                Value<String?> title = const Value.absent(),
                Value<String?> download = const Value.absent(),
                Value<String?> airDate = const Value.absent(),
              }) => AppBmfCompanion.insert(
                id: id,
                subject: subject,
                title: title,
                download: download,
                airDate: airDate,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppBmfTable, BmfRow>(table),
                  $$AppBmfTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({appSubscriptionRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (appSubscriptionRefs) db.appSubscription,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (appSubscriptionRefs)
                    await $_getPrefetchedData<
                      BmfRow,
                      $AppBmfTable,
                      SubscriptionRow
                    >(
                      currentTable: table,
                      referencedTable: $$AppBmfTableReferences
                          ._appSubscriptionRefsTable(db),
                      managerFromTypedResult: (p0) => $$AppBmfTableReferences(
                        db,
                        table,
                        p0,
                      ).appSubscriptionRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.bmfId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
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
      (BmfRow, $$AppBmfTableReferences),
      BmfRow,
      PrefetchHooks Function({bool appSubscriptionRefs})
    >;
typedef $$AppSubscriptionTableCreateCompanionBuilder =
    AppSubscriptionCompanion Function({
      Value<int> id,
      required int bmfId,
      Value<String> provider,
      required String url,
      required String feedKey,
      Value<String> sourceConfig,
      Value<int> autoUpdate,
      Value<String> status,
      Value<String> pendingItems,
      Value<String> knownItems,
      Value<int> hasBaseline,
      Value<int> itemKeyVersion,
    });
typedef $$AppSubscriptionTableUpdateCompanionBuilder =
    AppSubscriptionCompanion Function({
      Value<int> id,
      Value<int> bmfId,
      Value<String> provider,
      Value<String> url,
      Value<String> feedKey,
      Value<String> sourceConfig,
      Value<int> autoUpdate,
      Value<String> status,
      Value<String> pendingItems,
      Value<String> knownItems,
      Value<int> hasBaseline,
      Value<int> itemKeyVersion,
    });

final class $$AppSubscriptionTableReferences
    extends
        BaseReferences<_$BtDatabase, $AppSubscriptionTable, SubscriptionRow> {
  $$AppSubscriptionTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AppBmfTable _bmfIdTable(_$BtDatabase db) =>
      db.appBmf.createAlias('AppSubscription__bmfId__AppBmf__id');

  $$AppBmfTableProcessedTableManager get bmfId {
    final $_column = $_itemColumn<int>('bmfId')!;

    final manager = $$AppBmfTableTableManager(
      $_db,
      $_db.appBmf,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bmfIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AppSubscriptionTableFilterComposer
    extends Composer<_$BtDatabase, $AppSubscriptionTable> {
  $$AppSubscriptionTableFilterComposer({
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

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get feedKey => $composableBuilder(
    column: $table.feedKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceConfig => $composableBuilder(
    column: $table.sourceConfig,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get autoUpdate => $composableBuilder(
    column: $table.autoUpdate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pendingItems => $composableBuilder(
    column: $table.pendingItems,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get knownItems => $composableBuilder(
    column: $table.knownItems,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hasBaseline => $composableBuilder(
    column: $table.hasBaseline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemKeyVersion => $composableBuilder(
    column: $table.itemKeyVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$AppBmfTableFilterComposer get bmfId {
    final $$AppBmfTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bmfId,
      referencedTable: $db.appBmf,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppBmfTableFilterComposer(
            $db: $db,
            $table: $db.appBmf,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppSubscriptionTableOrderingComposer
    extends Composer<_$BtDatabase, $AppSubscriptionTable> {
  $$AppSubscriptionTableOrderingComposer({
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

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get feedKey => $composableBuilder(
    column: $table.feedKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceConfig => $composableBuilder(
    column: $table.sourceConfig,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get autoUpdate => $composableBuilder(
    column: $table.autoUpdate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingItems => $composableBuilder(
    column: $table.pendingItems,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get knownItems => $composableBuilder(
    column: $table.knownItems,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hasBaseline => $composableBuilder(
    column: $table.hasBaseline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemKeyVersion => $composableBuilder(
    column: $table.itemKeyVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$AppBmfTableOrderingComposer get bmfId {
    final $$AppBmfTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bmfId,
      referencedTable: $db.appBmf,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppBmfTableOrderingComposer(
            $db: $db,
            $table: $db.appBmf,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppSubscriptionTableAnnotationComposer
    extends Composer<_$BtDatabase, $AppSubscriptionTable> {
  $$AppSubscriptionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get feedKey =>
      $composableBuilder(column: $table.feedKey, builder: (column) => column);

  GeneratedColumn<String> get sourceConfig => $composableBuilder(
    column: $table.sourceConfig,
    builder: (column) => column,
  );

  GeneratedColumn<int> get autoUpdate => $composableBuilder(
    column: $table.autoUpdate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get pendingItems => $composableBuilder(
    column: $table.pendingItems,
    builder: (column) => column,
  );

  GeneratedColumn<String> get knownItems => $composableBuilder(
    column: $table.knownItems,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hasBaseline => $composableBuilder(
    column: $table.hasBaseline,
    builder: (column) => column,
  );

  GeneratedColumn<int> get itemKeyVersion => $composableBuilder(
    column: $table.itemKeyVersion,
    builder: (column) => column,
  );

  $$AppBmfTableAnnotationComposer get bmfId {
    final $$AppBmfTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bmfId,
      referencedTable: $db.appBmf,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppBmfTableAnnotationComposer(
            $db: $db,
            $table: $db.appBmf,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppSubscriptionTableTableManager
    extends
        RootTableManager<
          _$BtDatabase,
          $AppSubscriptionTable,
          SubscriptionRow,
          $$AppSubscriptionTableFilterComposer,
          $$AppSubscriptionTableOrderingComposer,
          $$AppSubscriptionTableAnnotationComposer,
          $$AppSubscriptionTableCreateCompanionBuilder,
          $$AppSubscriptionTableUpdateCompanionBuilder,
          (SubscriptionRow, $$AppSubscriptionTableReferences),
          SubscriptionRow,
          PrefetchHooks Function({bool bmfId})
        > {
  $$AppSubscriptionTableTableManager(
    _$BtDatabase db,
    $AppSubscriptionTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSubscriptionTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSubscriptionTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSubscriptionTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bmfId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> feedKey = const Value.absent(),
                Value<String> sourceConfig = const Value.absent(),
                Value<int> autoUpdate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> pendingItems = const Value.absent(),
                Value<String> knownItems = const Value.absent(),
                Value<int> hasBaseline = const Value.absent(),
                Value<int> itemKeyVersion = const Value.absent(),
              }) => AppSubscriptionCompanion(
                id: id,
                bmfId: bmfId,
                provider: provider,
                url: url,
                feedKey: feedKey,
                sourceConfig: sourceConfig,
                autoUpdate: autoUpdate,
                status: status,
                pendingItems: pendingItems,
                knownItems: knownItems,
                hasBaseline: hasBaseline,
                itemKeyVersion: itemKeyVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int bmfId,
                Value<String> provider = const Value.absent(),
                required String url,
                required String feedKey,
                Value<String> sourceConfig = const Value.absent(),
                Value<int> autoUpdate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> pendingItems = const Value.absent(),
                Value<String> knownItems = const Value.absent(),
                Value<int> hasBaseline = const Value.absent(),
                Value<int> itemKeyVersion = const Value.absent(),
              }) => AppSubscriptionCompanion.insert(
                id: id,
                bmfId: bmfId,
                provider: provider,
                url: url,
                feedKey: feedKey,
                sourceConfig: sourceConfig,
                autoUpdate: autoUpdate,
                status: status,
                pendingItems: pendingItems,
                knownItems: knownItems,
                hasBaseline: hasBaseline,
                itemKeyVersion: itemKeyVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSubscriptionTable, SubscriptionRow>(table),
                  $$AppSubscriptionTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bmfId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bmfId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bmfId,
                                referencedTable:
                                    $$AppSubscriptionTableReferences
                                        ._bmfIdTable(db),
                                referencedColumn:
                                    $$AppSubscriptionTableReferences
                                        ._bmfIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AppSubscriptionTableProcessedTableManager =
    ProcessedTableManager<
      _$BtDatabase,
      $AppSubscriptionTable,
      SubscriptionRow,
      $$AppSubscriptionTableFilterComposer,
      $$AppSubscriptionTableOrderingComposer,
      $$AppSubscriptionTableAnnotationComposer,
      $$AppSubscriptionTableCreateCompanionBuilder,
      $$AppSubscriptionTableUpdateCompanionBuilder,
      (SubscriptionRow, $$AppSubscriptionTableReferences),
      SubscriptionRow,
      PrefetchHooks Function({bool bmfId})
    >;
typedef $$AppRssCacheTableCreateCompanionBuilder =
    AppRssCacheCompanion Function({
      required String feedKey,
      required String requestUrl,
      Value<String?> data,
      Value<int> ttlMinutes,
      Value<int> lastSuccessAt,
      Value<int> lastAttemptAt,
      Value<int> lastFailedAt,
      Value<int> cacheVersion,
      Value<int> rowid,
    });
typedef $$AppRssCacheTableUpdateCompanionBuilder =
    AppRssCacheCompanion Function({
      Value<String> feedKey,
      Value<String> requestUrl,
      Value<String?> data,
      Value<int> ttlMinutes,
      Value<int> lastSuccessAt,
      Value<int> lastAttemptAt,
      Value<int> lastFailedAt,
      Value<int> cacheVersion,
      Value<int> rowid,
    });

class $$AppRssCacheTableFilterComposer
    extends Composer<_$BtDatabase, $AppRssCacheTable> {
  $$AppRssCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get feedKey => $composableBuilder(
    column: $table.feedKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestUrl => $composableBuilder(
    column: $table.requestUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ttlMinutes => $composableBuilder(
    column: $table.ttlMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastFailedAt => $composableBuilder(
    column: $table.lastFailedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cacheVersion => $composableBuilder(
    column: $table.cacheVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppRssCacheTableOrderingComposer
    extends Composer<_$BtDatabase, $AppRssCacheTable> {
  $$AppRssCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get feedKey => $composableBuilder(
    column: $table.feedKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestUrl => $composableBuilder(
    column: $table.requestUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ttlMinutes => $composableBuilder(
    column: $table.ttlMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastFailedAt => $composableBuilder(
    column: $table.lastFailedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cacheVersion => $composableBuilder(
    column: $table.cacheVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppRssCacheTableAnnotationComposer
    extends Composer<_$BtDatabase, $AppRssCacheTable> {
  $$AppRssCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get feedKey =>
      $composableBuilder(column: $table.feedKey, builder: (column) => column);

  GeneratedColumn<String> get requestUrl => $composableBuilder(
    column: $table.requestUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get ttlMinutes => $composableBuilder(
    column: $table.ttlMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastFailedAt => $composableBuilder(
    column: $table.lastFailedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cacheVersion => $composableBuilder(
    column: $table.cacheVersion,
    builder: (column) => column,
  );
}

class $$AppRssCacheTableTableManager
    extends
        RootTableManager<
          _$BtDatabase,
          $AppRssCacheTable,
          RssCacheRow,
          $$AppRssCacheTableFilterComposer,
          $$AppRssCacheTableOrderingComposer,
          $$AppRssCacheTableAnnotationComposer,
          $$AppRssCacheTableCreateCompanionBuilder,
          $$AppRssCacheTableUpdateCompanionBuilder,
          (
            RssCacheRow,
            BaseReferences<_$BtDatabase, $AppRssCacheTable, RssCacheRow>,
          ),
          RssCacheRow,
          PrefetchHooks Function()
        > {
  $$AppRssCacheTableTableManager(_$BtDatabase db, $AppRssCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppRssCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppRssCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppRssCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> feedKey = const Value.absent(),
                Value<String> requestUrl = const Value.absent(),
                Value<String?> data = const Value.absent(),
                Value<int> ttlMinutes = const Value.absent(),
                Value<int> lastSuccessAt = const Value.absent(),
                Value<int> lastAttemptAt = const Value.absent(),
                Value<int> lastFailedAt = const Value.absent(),
                Value<int> cacheVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppRssCacheCompanion(
                feedKey: feedKey,
                requestUrl: requestUrl,
                data: data,
                ttlMinutes: ttlMinutes,
                lastSuccessAt: lastSuccessAt,
                lastAttemptAt: lastAttemptAt,
                lastFailedAt: lastFailedAt,
                cacheVersion: cacheVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String feedKey,
                required String requestUrl,
                Value<String?> data = const Value.absent(),
                Value<int> ttlMinutes = const Value.absent(),
                Value<int> lastSuccessAt = const Value.absent(),
                Value<int> lastAttemptAt = const Value.absent(),
                Value<int> lastFailedAt = const Value.absent(),
                Value<int> cacheVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppRssCacheCompanion.insert(
                feedKey: feedKey,
                requestUrl: requestUrl,
                data: data,
                ttlMinutes: ttlMinutes,
                lastSuccessAt: lastSuccessAt,
                lastAttemptAt: lastAttemptAt,
                lastFailedAt: lastFailedAt,
                cacheVersion: cacheVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppRssCacheTable, RssCacheRow>(table),
                  BaseReferences<_$BtDatabase, $AppRssCacheTable, RssCacheRow>(
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

typedef $$AppRssCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$BtDatabase,
      $AppRssCacheTable,
      RssCacheRow,
      $$AppRssCacheTableFilterComposer,
      $$AppRssCacheTableOrderingComposer,
      $$AppRssCacheTableAnnotationComposer,
      $$AppRssCacheTableCreateCompanionBuilder,
      $$AppRssCacheTableUpdateCompanionBuilder,
      (
        RssCacheRow,
        BaseReferences<_$BtDatabase, $AppRssCacheTable, RssCacheRow>,
      ),
      RssCacheRow,
      PrefetchHooks Function()
    >;
typedef $$AppMigrationRecoveryTableCreateCompanionBuilder =
    AppMigrationRecoveryCompanion Function({
      Value<int> id,
      required int migrationVersion,
      required String kind,
      required String legacyKey,
      required String payload,
      Value<String> candidateBmfIds,
      required int createdAt,
      Value<int?> resolvedAt,
    });
typedef $$AppMigrationRecoveryTableUpdateCompanionBuilder =
    AppMigrationRecoveryCompanion Function({
      Value<int> id,
      Value<int> migrationVersion,
      Value<String> kind,
      Value<String> legacyKey,
      Value<String> payload,
      Value<String> candidateBmfIds,
      Value<int> createdAt,
      Value<int?> resolvedAt,
    });

class $$AppMigrationRecoveryTableFilterComposer
    extends Composer<_$BtDatabase, $AppMigrationRecoveryTable> {
  $$AppMigrationRecoveryTableFilterComposer({
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

  ColumnFilters<int> get migrationVersion => $composableBuilder(
    column: $table.migrationVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legacyKey => $composableBuilder(
    column: $table.legacyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get candidateBmfIds => $composableBuilder(
    column: $table.candidateBmfIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppMigrationRecoveryTableOrderingComposer
    extends Composer<_$BtDatabase, $AppMigrationRecoveryTable> {
  $$AppMigrationRecoveryTableOrderingComposer({
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

  ColumnOrderings<int> get migrationVersion => $composableBuilder(
    column: $table.migrationVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legacyKey => $composableBuilder(
    column: $table.legacyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get candidateBmfIds => $composableBuilder(
    column: $table.candidateBmfIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppMigrationRecoveryTableAnnotationComposer
    extends Composer<_$BtDatabase, $AppMigrationRecoveryTable> {
  $$AppMigrationRecoveryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get migrationVersion => $composableBuilder(
    column: $table.migrationVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get legacyKey =>
      $composableBuilder(column: $table.legacyKey, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get candidateBmfIds => $composableBuilder(
    column: $table.candidateBmfIds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );
}

class $$AppMigrationRecoveryTableTableManager
    extends
        RootTableManager<
          _$BtDatabase,
          $AppMigrationRecoveryTable,
          MigrationRecoveryRow,
          $$AppMigrationRecoveryTableFilterComposer,
          $$AppMigrationRecoveryTableOrderingComposer,
          $$AppMigrationRecoveryTableAnnotationComposer,
          $$AppMigrationRecoveryTableCreateCompanionBuilder,
          $$AppMigrationRecoveryTableUpdateCompanionBuilder,
          (
            MigrationRecoveryRow,
            BaseReferences<
              _$BtDatabase,
              $AppMigrationRecoveryTable,
              MigrationRecoveryRow
            >,
          ),
          MigrationRecoveryRow,
          PrefetchHooks Function()
        > {
  $$AppMigrationRecoveryTableTableManager(
    _$BtDatabase db,
    $AppMigrationRecoveryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppMigrationRecoveryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppMigrationRecoveryTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AppMigrationRecoveryTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> migrationVersion = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> legacyKey = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> candidateBmfIds = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> resolvedAt = const Value.absent(),
              }) => AppMigrationRecoveryCompanion(
                id: id,
                migrationVersion: migrationVersion,
                kind: kind,
                legacyKey: legacyKey,
                payload: payload,
                candidateBmfIds: candidateBmfIds,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int migrationVersion,
                required String kind,
                required String legacyKey,
                required String payload,
                Value<String> candidateBmfIds = const Value.absent(),
                required int createdAt,
                Value<int?> resolvedAt = const Value.absent(),
              }) => AppMigrationRecoveryCompanion.insert(
                id: id,
                migrationVersion: migrationVersion,
                kind: kind,
                legacyKey: legacyKey,
                payload: payload,
                candidateBmfIds: candidateBmfIds,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppMigrationRecoveryTable, MigrationRecoveryRow>(
                    table,
                  ),
                  BaseReferences<
                    _$BtDatabase,
                    $AppMigrationRecoveryTable,
                    MigrationRecoveryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppMigrationRecoveryTableProcessedTableManager =
    ProcessedTableManager<
      _$BtDatabase,
      $AppMigrationRecoveryTable,
      MigrationRecoveryRow,
      $$AppMigrationRecoveryTableFilterComposer,
      $$AppMigrationRecoveryTableOrderingComposer,
      $$AppMigrationRecoveryTableAnnotationComposer,
      $$AppMigrationRecoveryTableCreateCompanionBuilder,
      $$AppMigrationRecoveryTableUpdateCompanionBuilder,
      (
        MigrationRecoveryRow,
        BaseReferences<
          _$BtDatabase,
          $AppMigrationRecoveryTable,
          MigrationRecoveryRow
        >,
      ),
      MigrationRecoveryRow,
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
  $$AppSubscriptionTableTableManager get appSubscription =>
      $$AppSubscriptionTableTableManager(_db, _db.appSubscription);
  $$AppRssCacheTableTableManager get appRssCache =>
      $$AppRssCacheTableTableManager(_db, _db.appRssCache);
  $$AppMigrationRecoveryTableTableManager get appMigrationRecovery =>
      $$AppMigrationRecoveryTableTableManager(_db, _db.appMigrationRecovery);
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
