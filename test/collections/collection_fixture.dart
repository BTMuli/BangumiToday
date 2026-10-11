// Project imports:
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';

BangumiUserSubjectCollection collectionFixture({
  int id = 536270,
  BangumiCollectionType type = BangumiCollectionType.doing,
  int epStatus = 1,
}) => BangumiUserSubjectCollection(
  subjectId: id,
  subjectType: BangumiSubjectType.anime,
  rate: 7,
  type: type,
  comment: '保留短评',
  tags: ['保留标签'],
  epStatus: epStatus,
  volStatus: 0,
  updatedAt: '2026-10-11T22:07:58+08:00',
  private: true,
  subject: BangumiSlimSubject(
    id: id,
    type: BangumiSubjectType.anime,
    name: '目覚めたら最強装備と宇宙船持ちだったので、',
    nameCn: '一觉醒来坐拥神装和飞船',
    shortSummary: '',
    date: '2026-10-01',
    images: BangumiImages(
      large: '',
      common: '',
      medium: '',
      small: '',
      grid: '',
    ),
    volumes: 0,
    eps: 12,
    collectionTotal: 100,
    score: 7,
    tags: [],
  ),
);
