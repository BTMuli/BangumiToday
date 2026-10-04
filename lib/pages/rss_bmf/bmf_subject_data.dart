/// 工作台只复用本地条目数据，不为列表额外请求条目详情。
class BmfSubjectData {
  final String? imageUrl;
  final String? airDate;
  final List<String> names;

  const BmfSubjectData({this.imageUrl, this.airDate, this.names = const []});

  factory BmfSubjectData.fromSources({
    required List<String?> covers,
    required List<String?> dates,
    required List<String?> names,
  }) {
    Iterable<String> texts(List<String?> values) =>
        values.whereType<String>().map((value) => value.trim()).where(_hasText);
    return BmfSubjectData(
      imageUrl: texts(covers).firstOrNull,
      airDate: texts(dates).firstOrNull,
      names: texts(names).toSet().toList(),
    );
  }

  static bool _hasText(String value) => value.trim().isNotEmpty;
}
