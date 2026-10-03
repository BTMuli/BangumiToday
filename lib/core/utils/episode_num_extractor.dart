enum EpisodeNumberKind { single, ambiguous, batch, special, seasonal, unknown }

class EpisodeNumberResult {
  const EpisodeNumberResult(this.kind, {this.number, this.evidence});

  final EpisodeNumberKind kind;
  final int? number;
  final String? evidence;

  String get reason => switch (kind) {
    EpisodeNumberKind.single => '明确的单集编号',
    EpisodeNumberKind.ambiguous => '文件名存在多个集数候选',
    EpisodeNumberKind.batch => '合集文件不能对应单个章节',
    EpisodeNumberKind.special => '特别篇或小数集需要手动选择章节',
    EpisodeNumberKind.seasonal => '季编号尚未建立可靠的章节映射',
    EpisodeNumberKind.unknown => '文件名没有可靠的单集编号',
  };
}

/// Conservative filename evidence; display labels are not mapping evidence.
EpisodeNumberResult extractEpisodeNumber(String filePath) {
  var name = filePath.split(RegExp(r'[/\\]')).last;
  name = name.replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '');
  if (RegExp(
        r'\b(?:BATCH|COMPLETE)\b|合集|全集',
        caseSensitive: false,
      ).hasMatch(name) ||
      RegExp(
        r'(?:\bEP?\s*)?\d{1,4}(?:v\d+)?\s*[-+~～至]\s*'
        r'(?:EP?\s*)?\d{1,4}',
        caseSensitive: false,
      ).hasMatch(name)) {
    return const EpisodeNumberResult(EpisodeNumberKind.batch);
  }
  if (RegExp(
    r'\bS\d{1,2}\s*E\d+|\bSeason\s*\d+|第\d+季',
    caseSensitive: false,
  ).hasMatch(name)) {
    return const EpisodeNumberResult(EpisodeNumberKind.seasonal);
  }
  if (RegExp(
        r'\b(?:SP|OVA|OAD|OP|ED)(?:\d+)?\b|特别篇|特別篇|特典',
        caseSensitive: false,
      ).hasMatch(name) ||
      RegExp(
        r'(?:\bEP?|第|[\s\[\]-])\d+\.\d+(?=话|話|集|[\s\])]|$)',
        caseSensitive: false,
      ).hasMatch(name)) {
    return const EpisodeNumberResult(EpisodeNumberKind.special);
  }
  var candidates = <int, String>{};
  var patterns = [
    RegExp(
      r'(?<![A-Za-z0-9])EP?\s*(\d{1,4})(?:v\d+)?'
      r'(?![\dA-Za-z.])',
      caseSensitive: false,
    ),
    RegExp(r'第\s*(\d{1,4})(?:v\d+)?\s*[话話集]', caseSensitive: false),
    RegExp(
      r'(?:\s-\s|\s—\s)(\d{1,4})(?:v\d+)?(?=$|[\s\[\]()])',
      caseSensitive: false,
    ),
    RegExp(r'\[\s*(\d{1,4})(?:v\d+)?\s*\]', caseSensitive: false),
  ];
  for (var pattern in patterns) {
    for (var match in pattern.allMatches(name)) {
      var number = int.parse(match.group(1)!);
      if (number <= 0 ||
          (number >= 1900 && number <= 2099) ||
          {360, 480, 576, 720, 1080, 1440, 2160, 4320}.contains(number)) {
        continue;
      }
      candidates[number] = match.group(0)!;
    }
  }
  if (candidates.length > 1) {
    return const EpisodeNumberResult(EpisodeNumberKind.ambiguous);
  }
  if (candidates.isEmpty) {
    return const EpisodeNumberResult(EpisodeNumberKind.unknown);
  }
  return EpisodeNumberResult(
    EpisodeNumberKind.single,
    number: candidates.keys.single,
    evidence: candidates.values.single,
  );
}
