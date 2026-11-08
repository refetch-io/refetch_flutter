import 'package:flutter_test/flutter_test.dart';
import 'package:refetch/features/thread/domain/comment.dart';

Comment _row(String id, {String? reply, required int minute, int count = 0}) =>
    Comment.fromRow({
      r'$id': id,
      r'$createdAt': DateTime.utc(2026, 11, 8, 8, minute).toIso8601String(),
      'userName': 'user-$id',
      'content': 'text $id',
      'replyId': reply ?? '',
      'count': count,
    });

void main() {
  test('Comment.fromRow maps a comments-table row', () {
    final c = _row('a', minute: 5, count: 3);
    expect(c.id, 'a');
    expect(c.author, 'user-a');
    expect(c.text, 'text a');
    expect(c.count, 3);
    expect(c.parentId, isNull, reason: 'an empty replyId means top level');
    expect(c.createdAt, DateTime.utc(2026, 11, 8, 8, 5));
  });

  test('missing name falls back to Anonymous', () {
    expect(Comment.fromRow({r'$id': 'x'}).author, 'Anonymous');
  });

  group('buildTree', () {
    test('nests replies under parents, oldest first, with depth', () {
      // Rows arrive newest first, as the thread query orders them.
      final flat = [
        _row('r2', reply: 'root1', minute: 4),
        _row('root2', minute: 3),
        _row('r1', reply: 'root1', minute: 2),
        _row('rr', reply: 'r1', minute: 6),
        _row('root1', minute: 1),
      ];

      final tree = Comment.buildTree(flat, votes: {'rr': 'up'});

      expect(tree.map((c) => c.id), ['root1', 'root2']);
      final root1 = tree.first;
      expect(root1.depth, 0);
      expect(root1.replies.map((c) => c.id), ['r1', 'r2']);
      expect(root1.replies.first.depth, 1);
      final rr = root1.replies.first.replies.single;
      expect(rr.id, 'rr');
      expect(rr.depth, 2);
      expect(rr.currentVote, 'up');
      expect(Comment.flatten(tree).length, 5);
    });

    test('promotes replies whose parent is gone, as the web does', () {
      final tree = Comment.buildTree([
        _row('orphan', reply: 'deleted', minute: 2),
        _row('root', minute: 1),
      ]);
      expect(tree.map((c) => c.id), ['root', 'orphan']);
    });

    test('a self-referencing reply cannot loop', () {
      final tree = Comment.buildTree([_row('self', reply: 'self', minute: 1)]);
      expect(tree.single.id, 'self');
      expect(tree.single.replies, isEmpty);
    });
  });
}
