// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'app_subscription_model.dart';

part 'app_bmf_model.g.dart';

/// BMF directory association plus its complete subscription collection.
@JsonSerializable(explicitToJson: true)
class AppBmfModel {
  static const _unset = Object();

  AppBmfModel({
    this.id = -1,
    required this.subject,
    this.title,
    this.airDate,
    this.download,
    List<AppSubscriptionModel>? subscriptions,
    String? rss,
    bool? autoUpdate,
  }) : subscriptions = List.of(subscriptions ?? const []) {
    if (rss != null && rss.trim().isNotEmpty) {
      this.rss = rss;
    }
    if (autoUpdate != null) this.autoUpdate = autoUpdate;
  }

  final int id;
  final int subject;
  String? title;
  String? airDate;
  String? download;
  List<AppSubscriptionModel> subscriptions;

  // Convenience for existing subscribe actions: adding a source never replaces
  // the collection. Editing/removing sources uses explicit subscription IDs.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get rss => subscriptions.firstOrNull?.url;
  set rss(String? value) {
    if (value == null || value.trim().isEmpty) {
      if (subscriptions.isNotEmpty) subscriptions.removeAt(0);
      return;
    }
    var draft = AppSubscriptionModel.forUrl(value, bmfId: id);
    if (subscriptions.any((s) => s.feedKey == draft.feedKey)) return;
    subscriptions.add(draft);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get autoUpdate => subscriptions.any((s) => s.autoUpdate);
  set autoUpdate(bool value) {
    subscriptions = subscriptions
        .map((s) => s.copyWith(autoUpdate: value))
        .toList();
  }

  AppBmfModel copyWith({
    Object? id = _unset,
    Object? subject = _unset,
    Object? title = _unset,
    Object? airDate = _unset,
    Object? download = _unset,
    Object? rss = _unset,
    Object? autoUpdate = _unset,
    List<AppSubscriptionModel>? subscriptions,
  }) {
    var model = AppBmfModel(
      id: id == _unset ? this.id : id as int,
      subject: subject == _unset ? this.subject : subject as int,
      title: title == _unset ? this.title : title as String?,
      airDate: airDate == _unset ? this.airDate : airDate as String?,
      download: download == _unset ? this.download : download as String?,
      subscriptions: subscriptions ?? this.subscriptions,
    );
    if (rss != _unset) model.rss = rss as String?;
    if (autoUpdate != _unset) model.autoUpdate = autoUpdate as bool;
    return model;
  }

  factory AppBmfModel.fromJson(Map<String, dynamic> json) =>
      _$AppBmfModelFromJson(json);
  Map<String, dynamic> toJson() => _$AppBmfModelToJson(this);
}
