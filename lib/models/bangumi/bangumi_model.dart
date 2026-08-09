/// Bangumi API 数据模型入口。
///
/// 按领域拆分为多个子库，每个子库携带独立的生成代码；
/// 此处统一 re-export，保持既有导入路径兼容。
library;

export 'bangumi_model_character.dart';
export 'bangumi_model_collection.dart';
export 'bangumi_model_episode.dart';
export 'bangumi_model_error.dart';
export 'bangumi_model_index.dart';
export 'bangumi_model_legacy.dart';
export 'bangumi_model_person.dart';
export 'bangumi_model_revision.dart';
export 'bangumi_model_subject.dart';
export 'bangumi_model_user.dart';
