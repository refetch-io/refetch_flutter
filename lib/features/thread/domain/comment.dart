import '../../../core/format/time_ago.dart' as format;

/// A comment on a story, read from the Appwrite comments table. Rows are flat
/// (`replyId` points at the parent); [Comment.buildTree] nests them the way the
/// web's `buildCommentTree` does.
class Comment {
  const Comment({
    required this.id,
    required this.author,
    required this.text,
    required this.count,
    required this.replies,
    required this.depth,
    this.createdAt,
    this.userId,
    this.parentId,
    this.currentVote,
  });

  final String id;
  final String author;
  final String text;
  final int count;
  final List<Comment> replies;
  final int depth;
  final DateTime? createdAt;
  final String? userId;
  final String? parentId;

  /// `'up'`, `'down'`, or `null`; filled in from `/api/app/votes`.
  final String? currentVote;

  String get timeAgo => createdAt == null ? '' : format.timeAgo(createdAt!);

  /// Columns the thread selects (the web's `COMMENT_FIELDS`, minus the
  /// optional ones older databases lack).
  static const fields = [
    r'$id',
    r'$createdAt',
    'postId',
    'userId',
    'userName',
    'content',
    'replyId',
    'count',
  ];

  factory Comment.fromRow(Map<String, dynamic> row) {
    final userName = row['userName'];
    final replyId = row['replyId'];
    final count = row['count'];
    return Comment(
      id: '${row[r'$id']}',
      author: userName is String && userName.isNotEmpty
          ? userName
          : 'Anonymous',
      text: '${row['content'] ?? ''}',
      count: count is num ? count.toInt() : 0,
      createdAt: DateTime.tryParse('${row[r'$createdAt'] ?? ''}'),
      userId: row['userId'] is String ? row['userId'] as String : null,
      parentId: replyId is String && replyId.isNotEmpty ? replyId : null,
      depth: 0,
      replies: const [],
    );
  }

  /// Nests flat comments into a reply tree. Top-level comments are oldest
  /// first, as are replies; a reply whose parent is gone becomes top-level.
  /// [votes] maps comment id → the viewer's vote.
  static List<Comment> buildTree(
    List<Comment> flat, {
    Map<String, String> votes = const {},
  }) {
    final byParent = <String?, List<Comment>>{};
    final ids = {for (final c in flat) c.id};
    for (final comment in flat) {
      final parent = comment.parentId;
      final key = parent != null && parent != comment.id && ids.contains(parent)
          ? parent
          : null;
      byParent.putIfAbsent(key, () => []).add(comment);
    }

    int oldest(Comment a, Comment b) {
      final at = a.createdAt, bt = b.createdAt;
      if (at == null || bt == null) return 0;
      return at.compareTo(bt);
    }

    final visited = <String>{};
    List<Comment> build(String? parent, int depth) {
      final children = [...?byParent[parent]]..sort(oldest);
      return [
        for (final c in children)
          if (visited.add(c.id))
            Comment(
              id: c.id,
              author: c.author,
              text: c.text,
              count: c.count,
              createdAt: c.createdAt,
              userId: c.userId,
              parentId: c.parentId,
              currentVote: votes[c.id],
              depth: depth,
              replies: build(c.id, depth + 1),
            ),
      ];
    }

    return build(null, 0);
  }

  /// Every comment in [tree], depth first.
  static Iterable<Comment> flatten(List<Comment> tree) sync* {
    for (final c in tree) {
      yield c;
      yield* flatten(c.replies);
    }
  }
}
