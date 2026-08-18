// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../database/app/app_config.dart';

/// 条目详情布局。
enum SubjectDetailLayoutMode {
  /// 现有单列滚动布局
  current,

  /// 身份带 + 操作条
  a,
}

extension SubjectDetailLayoutModeX on SubjectDetailLayoutMode {
  String get shortLabel {
    switch (this) {
      case SubjectDetailLayoutMode.current:
        return '原版';
      case SubjectDetailLayoutMode.a:
        return '新布局';
    }
  }

  String get tooltip {
    switch (this) {
      case SubjectDetailLayoutMode.current:
        return '原版：单列滚动';
      case SubjectDetailLayoutMode.a:
        return '新布局：身份带 + 操作条';
    }
  }

  static SubjectDetailLayoutMode? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (var mode in SubjectDetailLayoutMode.values) {
      if (mode.name == raw) return mode;
    }
    return null;
  }
}

class SubjectDetailLayoutModeNotifier
    extends Notifier<SubjectDetailLayoutMode> {
  @override
  SubjectDetailLayoutMode build() {
    unawaited(_hydrate());
    return SubjectDetailLayoutMode.current;
  }

  Future<void> _hydrate() async {
    try {
      var saved = await BtsAppConfig().readSubjectDetailLayout();
      var mode = SubjectDetailLayoutModeX.tryParse(saved);
      if (!ref.mounted || mode == null || state == mode) return;
      state = mode;
    } on Object {
      return;
    }
  }

  void setMode(SubjectDetailLayoutMode mode) {
    if (state == mode) return;
    state = mode;
    unawaited(_persist(mode));
  }

  Future<void> _persist(SubjectDetailLayoutMode mode) async {
    try {
      await BtsAppConfig().writeSubjectDetailLayout(mode.name);
    } on Object {
      return;
    }
  }
}

final subjectDetailLayoutModeProvider =
    NotifierProvider<SubjectDetailLayoutModeNotifier, SubjectDetailLayoutMode>(
      SubjectDetailLayoutModeNotifier.new,
    );
