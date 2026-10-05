// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import '../../domain/rss/feed_identity.dart';

part 'app_subscription_model.g.dart';

@JsonSerializable()
class AppSubscriptionModel {
  AppSubscriptionModel({
    this.id = -1,
    this.bmfId = -1,
    required this.provider,
    required this.url,
    required this.feedKey,
    this.sourceConfig = '{"version":1}',
    bool? autoUpdate,
    this.status = 'active',
    this.pendingItems = '[]',
    this.knownItems = '[]',
    bool? hasBaseline,
    this.itemKeyVersion = 1,
  }) : autoUpdate = autoUpdate ?? true,
       hasBaseline = hasBaseline ?? false;

  factory AppSubscriptionModel.forUrl(
    String url, {
    int bmfId = -1,
    bool autoUpdate = true,
    String sourceConfig = '{"version":1}',
  }) {
    var config = RssSourceConfig.decode(sourceConfig);
    var identity = FeedIdentity.fromUrl(
      url,
      legacyBmfId: bmfId,
      config: config,
    );
    return AppSubscriptionModel(
      bmfId: bmfId,
      provider: identity.provider,
      url: identity.url,
      feedKey: identity.feedKey,
      sourceConfig: sourceConfig,
      autoUpdate: autoUpdate,
      status: identity.isValid && config.isSupported ? 'active' : 'needsReview',
    );
  }

  final int id;
  final int bmfId;
  final String provider;
  final String url;
  final String feedKey;
  final String sourceConfig;
  @JsonKey(fromJson: _autoUpdateFromSql)
  final bool autoUpdate;
  final String status;
  final String pendingItems;
  final String knownItems;
  @JsonKey(fromJson: _boolFromSql)
  final bool hasBaseline;
  final int itemKeyVersion;

  bool get canRefresh =>
      status == 'active' &&
      itemKeyVersion == 1 &&
      RssSourceConfig.decode(sourceConfig).isSupported &&
      FeedIdentity.fromUrl(
            url,
            legacyBmfId: bmfId,
            config: RssSourceConfig.decode(sourceConfig),
          ).feedKey ==
          feedKey &&
      feedKey.startsWith('rss:v1:');

  Set<String> get pendingItemKeys => decodeKeys(pendingItems);
  Set<String> get knownItemKeys => decodeKeys(knownItems);

  static Set<String> decodeKeys(String value) {
    var decoded = jsonDecode(value);
    if (decoded is! List || decoded.any((item) => item is! String)) {
      throw const FormatException('RSS item keys must be strings');
    }
    return decoded.cast<String>().toSet();
  }

  static bool _autoUpdateFromSql(Object? value) =>
      value == null || _boolFromSql(value);
  static bool _boolFromSql(Object? value) => value is bool ? value : value == 1;

  AppSubscriptionModel copyWith({
    String? url,
    bool? autoUpdate,
    String? sourceConfig,
    String? status,
  }) {
    var configValue = sourceConfig ?? this.sourceConfig;
    var identity = FeedIdentity.fromUrl(
      url ?? this.url,
      legacyBmfId: bmfId,
      config: RssSourceConfig.decode(configValue),
    );
    return AppSubscriptionModel(
      id: id,
      bmfId: bmfId,
      provider: identity.provider,
      url: identity.url,
      feedKey: identity.feedKey,
      sourceConfig: configValue,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      status: status ?? this.status,
      pendingItems: pendingItems,
      knownItems: knownItems,
      hasBaseline: hasBaseline,
      itemKeyVersion: itemKeyVersion,
    );
  }

  factory AppSubscriptionModel.fromJson(Map<String, dynamic> json) =>
      _$AppSubscriptionModelFromJson(json);
  Map<String, dynamic> toJson() => _$AppSubscriptionModelToJson(this);
}
