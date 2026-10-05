// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_subscription_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSubscriptionModel _$AppSubscriptionModelFromJson(
  Map<String, dynamic> json,
) => AppSubscriptionModel(
  id: (json['id'] as num?)?.toInt() ?? -1,
  bmfId: (json['bmfId'] as num?)?.toInt() ?? -1,
  provider: json['provider'] as String,
  url: json['url'] as String,
  feedKey: json['feedKey'] as String,
  sourceConfig: json['sourceConfig'] as String? ?? '{"version":1}',
  autoUpdate: AppSubscriptionModel._autoUpdateFromSql(json['autoUpdate']),
  status: json['status'] as String? ?? 'active',
  pendingItems: json['pendingItems'] as String? ?? '[]',
  knownItems: json['knownItems'] as String? ?? '[]',
  hasBaseline: AppSubscriptionModel._boolFromSql(json['hasBaseline']),
  itemKeyVersion: (json['itemKeyVersion'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$AppSubscriptionModelToJson(
  AppSubscriptionModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'bmfId': instance.bmfId,
  'provider': instance.provider,
  'url': instance.url,
  'feedKey': instance.feedKey,
  'sourceConfig': instance.sourceConfig,
  'autoUpdate': instance.autoUpdate,
  'status': instance.status,
  'pendingItems': instance.pendingItems,
  'knownItems': instance.knownItems,
  'hasBaseline': instance.hasBaseline,
  'itemKeyVersion': instance.itemKeyVersion,
};
