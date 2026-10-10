// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model_person.dart';
import 'package:bangumi_today/pages/subject_detail/subject_detail_staff_groups.dart';

BangumiRelatedPerson _person(
  int id,
  String position, {
  String name = '制作人员',
  String eps = '',
}) => BangumiRelatedPerson(
  id: id,
  name: name,
  type: BangumiPersonType.person,
  career: [],
  images: null,
  relation: position,
  eps: eps,
);

void main() {
  test('按人物 ID 合并多个职位，章节保持对应职位并去重', () {
    var persons = [
      _person(1, '导演', eps: '1'),
      _person(2, '脚本'),
      _person(1, '脚本', eps: '2、3'),
      _person(1, '导演', eps: ' 1 '),
      _person(1, '导演', eps: '4'),
      _person(1, '脚本', eps: '  '),
    ];
    var groups = SubjectStaffGroups.fromPersons(persons);

    expect(groups.members.map((member) => member.person.id), [1, 2]);
    expect(groups.members.first.positions, {
      '导演': ['1', '4'],
      '脚本': ['2、3'],
    });
    expect(groups.members.last.positions, {'脚本': <String>[]});
    expect(persons.map((person) => person.relation), [
      '导演',
      '脚本',
      '脚本',
      '导演',
      '导演',
      '脚本',
    ]);
    expect(persons[3].eps, ' 1 ');
  });

  test('按职位合并人物，重复记录不产生重复卡片或跨职位章节', () {
    var groups = SubjectStaffGroups.fromPersons([
      _person(1, '导演', eps: '1'),
      _person(2, '脚本', eps: '2'),
      _person(1, '脚本', eps: '3'),
      _person(1, '导演', eps: '4'),
      _person(2, '脚本', eps: '2'),
    ]);

    expect(groups.positions.map((group) => group.position), ['导演', '脚本']);
    var directors = groups.positions.first.members;
    expect(directors.single.person.id, 1);
    expect(directors.single.positions, {
      '导演': ['1', '4'],
    });
    var writers = groups.positions.last.members;
    expect(writers.map((member) => member.person.id), [2, 1]);
    expect(writers.first.positions, {
      '脚本': ['2'],
    });
    expect(writers.last.positions, {
      '脚本': ['3'],
    });
  });

  test('同名但 ID 不同的人物保持独立', () {
    var groups = SubjectStaffGroups.fromPersons([
      _person(1, '原画', name: '同名人员'),
      _person(2, '原画', name: '同名人员'),
    ]);

    expect(groups.members.map((member) => member.person.id), [1, 2]);
    expect(groups.positions.single.members.map((member) => member.person.id), [
      1,
      2,
    ]);
  });

  test('空列表不产生人物或职位分组', () {
    var groups = SubjectStaffGroups.fromPersons([]);

    expect(groups.members, isEmpty);
    expect(groups.positions, isEmpty);
  });
}
