/// 搜索日期范围使用自然日，结束日期包含当天。
class SubjectSearchDateRange {
  const SubjectSearchDateRange({this.from, this.to});

  factory SubjectSearchDateRange.year(int year) => SubjectSearchDateRange(
    from: DateTime(year),
    to: DateTime(year + 1, 1, 0),
  );

  factory SubjectSearchDateRange.quarter(int year, int quarter) {
    RangeError.checkValueInInterval(quarter, 1, 4, 'quarter');
    return SubjectSearchDateRange(
      from: DateTime(year, (quarter - 1) * 3 + 1),
      to: DateTime(year, quarter * 3 + 1, 0),
    );
  }

  final DateTime? from;
  final DateTime? to;

  String get dateFrom => _format(from);
  String get dateTo => _format(to);

  static String _format(DateTime? date) => date == null
      ? ''
      : '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';

  SubjectSearchDateRange withFrom(DateTime? value) {
    var day = value == null
        ? null
        : DateTime(value.year, value.month, value.day);
    return SubjectSearchDateRange(
      from: day,
      to: day != null && to != null && day.isAfter(to!) ? day : to,
    );
  }

  SubjectSearchDateRange withTo(DateTime? value) {
    var day = value == null
        ? null
        : DateTime(value.year, value.month, value.day);
    return SubjectSearchDateRange(
      from: day != null && from != null && day.isBefore(from!) ? day : from,
      to: day,
    );
  }

  int? get wholeYear {
    var start = from;
    if (start == null) return null;
    return this == SubjectSearchDateRange.year(start.year) ? start.year : null;
  }

  int? get quarterNumber {
    var start = from;
    if (start == null) return null;
    var quarter = (start.month - 1) ~/ 3 + 1;
    return this == SubjectSearchDateRange.quarter(start.year, quarter)
        ? quarter
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is SubjectSearchDateRange && from == other.from && to == other.to;

  @override
  int get hashCode => Object.hash(from, to);
}
