// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/models/bangumi/bangumi_model_comment.dart';

Map<String, dynamic> _comment(int id) => {
  'id': id,
  'mainID': 522,
  'creatorID': 123,
  'relatedID': 0,
  'createdAt': 1700000000,
  'content': 'comment $id',
  'state': 0,
};

Map<String, dynamic> _user() => {
  'id': 123,
  'username': 'test-user',
  'nickname': 'Test User',
  'avatar': {
    'large': 'https://example.test/avatar-large.jpg',
    'medium': 'https://example.test/avatar-medium.jpg',
    'small': 'https://example.test/avatar-small.jpg',
  },
};

void main() {
  test('comments and replies accept absent authors', () {
    var comment = BangumiEpisodeComment.fromJson({
      ..._comment(1),
      'replies': [_comment(2)],
    });

    expect(comment.user, isNull);
    expect(comment.content, 'comment 1');
    expect(comment.replies.single.user, isNull);
    expect(comment.replies.single.content, 'comment 2');
    expect(comment.toJson()['user'], isNull);
    expect(comment.replies.single.toJson()['user'], isNull);
  });

  test('comments and replies accept explicit null authors', () {
    var comment = BangumiEpisodeComment.fromJson({
      ..._comment(1),
      'user': null,
      'replies': [
        {..._comment(2), 'user': null},
      ],
    });

    expect(comment.user, isNull);
    expect(comment.replies.single.user, isNull);
  });

  test('available authors survive serialization', () {
    var comment = BangumiEpisodeComment.fromJson({
      ..._comment(1),
      'user': _user(),
      'replies': [
        {..._comment(2), 'user': _user()},
      ],
    });
    var restored = BangumiEpisodeComment.fromJson(comment.toJson());

    expect(restored.user!.username, 'test-user');
    expect(restored.user!.avatar.medium, _user()['avatar']['medium']);
    expect(restored.replies.single.user!.nickname, 'Test User');
  });

  test('missing authors do not prevent decoding the remaining comments', () {
    var comments = [
      {..._comment(1), 'replies': <Object>[]},
      {..._comment(2), 'user': _user(), 'replies': <Object>[]},
    ].map(BangumiEpisodeComment.fromJson).toList();

    expect(comments.map((comment) => comment.id), [1, 2]);
    expect(comments.last.user!.id, 123);
  });

  test('malformed author data still fails decoding', () {
    expect(
      () => BangumiEpisodeComment.fromJson({
        ..._comment(1),
        'user': 123,
        'replies': <Object>[],
      }),
      throwsA(isA<TypeError>()),
    );
  });
}
