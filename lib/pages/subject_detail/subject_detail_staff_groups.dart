// Project imports:
import '../../models/bangumi/bangumi_model_person.dart';

/// 同一人物的职位及各职位对应的参与章节 / 曲目。
class SubjectStaffMember {
  const SubjectStaffMember({required this.person, required this.positions});

  final BangumiRelatedPerson person;
  final Map<String, List<String>> positions;
}

class SubjectStaffPositionGroup {
  const SubjectStaffPositionGroup({
    required this.position,
    required this.members,
  });

  final String position;
  final List<SubjectStaffMember> members;
}

/// 保留接口首次出现的顺序，分别按人物 ID 和职位合并。
class SubjectStaffGroups {
  const SubjectStaffGroups({required this.members, required this.positions});

  factory SubjectStaffGroups.fromPersons(List<BangumiRelatedPerson> persons) {
    var byPosition = <String, List<BangumiRelatedPerson>>{};
    for (var person in persons) {
      byPosition.putIfAbsent(person.relation, () => []).add(person);
    }
    return SubjectStaffGroups(
      members: _mergeMembers(persons),
      positions: [
        for (var entry in byPosition.entries)
          SubjectStaffPositionGroup(
            position: entry.key,
            members: _mergeMembers(entry.value),
          ),
      ],
    );
  }

  final List<SubjectStaffMember> members;
  final List<SubjectStaffPositionGroup> positions;

  static List<SubjectStaffMember> _mergeMembers(
    List<BangumiRelatedPerson> persons,
  ) {
    var byPerson = <int, List<BangumiRelatedPerson>>{};
    for (var person in persons) {
      byPerson.putIfAbsent(person.id, () => []).add(person);
    }
    return [for (var entries in byPerson.values) _mergeMember(entries)];
  }

  static SubjectStaffMember _mergeMember(List<BangumiRelatedPerson> entries) {
    var positions = <String, Set<String>>{};
    for (var entry in entries) {
      var episodes = positions.putIfAbsent(entry.relation, () => {});
      var eps = entry.eps.trim();
      if (eps.isNotEmpty) episodes.add(eps);
    }
    return SubjectStaffMember(
      person: entries.first,
      positions: {
        for (var entry in positions.entries) entry.key: entry.value.toList(),
      },
    );
  }
}
