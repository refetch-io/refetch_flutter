import '../../../core/config/app_config.dart';
import '../../../core/format/time_ago.dart' as format;

/// A story (a submitted link or "show" post), read from the Appwrite posts
/// table. Mirrors `toPost`/`toPostDetail` in the web repo's `db.server.ts`.
class Post {
  const Post({
    required this.id,
    required this.title,
    required this.domain,
    required this.count,
    required this.author,
    required this.countComments,
    this.createdAt,
    this.description,
    this.tldr,
    this.userId,
    this.link,
    this.type,
    this.readingTime,
    this.currentVote,
  });

  final String id;
  final String title;

  /// Host of [link] without `www.`, or empty for a post without a link.
  final String domain;
  final int count;
  final String author;
  final int countComments;
  final DateTime? createdAt;
  final String? description;
  final String? tldr;
  final String? userId;
  final String? link;

  /// `'link'` or `'show'`.
  final String? type;
  final int? readingTime;

  /// `'up'`, `'down'`, or `null`; filled in from `/api/app/votes`.
  final String? currentVote;

  bool get isShow => type == 'show';

  /// "3h ago", or null when the row carried no creation time.
  String? get timeAgo => createdAt == null ? null : format.timeAgo(createdAt!);

  /// The thread on refetch.io, for sharing.
  String get threadUrl => '${AppConfig.apiBaseUrl}/threads/$id';

  /// Columns the feed selects (the web's `POST_LIST_FIELDS`).
  static const listFields = [
    r'$id',
    r'$createdAt',
    'title',
    'description',
    'userId',
    'userName',
    'count',
    'countComments',
    'link',
    'type',
    'readingTime',
  ];

  /// Builds a post from a TablesDB row's data (which includes `$id` and
  /// `$createdAt`).
  factory Post.fromRow(Map<String, dynamic> row, {String? currentVote}) {
    final rawLink = row['link'];
    final link =
        rawLink is String &&
            RegExp(r'^https?://', caseSensitive: false).hasMatch(rawLink)
        ? rawLink
        : null;
    final userName = row['userName'];
    final tldr = row['tldr'];
    final readingTime = row['readingTime'];
    final description = row['description'];
    return Post(
      id: '${row[r'$id']}',
      title: '${row['title'] ?? ''}',
      domain: hostOf(link),
      count: _asInt(row['count']),
      author: userName is String && userName.isNotEmpty
          ? userName
          : 'Anonymous',
      countComments: _asInt(row['countComments']),
      createdAt: DateTime.tryParse('${row[r'$createdAt'] ?? ''}'),
      description: description is String && description.trim().isNotEmpty
          ? description.trim()
          : null,
      tldr: tldr is String && tldr.trim().isNotEmpty ? tldr.trim() : null,
      userId: row['userId'] is String ? row['userId'] as String : null,
      link: link,
      type: row['type'] == 'show' ? 'show' : 'link',
      readingTime: readingTime is num && readingTime > 0
          ? readingTime.toInt()
          : null,
      currentVote: currentVote,
    );
  }

  Post withVote(String? vote) => Post(
    id: id,
    title: title,
    domain: domain,
    count: count,
    author: author,
    countComments: countComments,
    createdAt: createdAt,
    description: description,
    tldr: tldr,
    userId: userId,
    link: link,
    type: type,
    readingTime: readingTime,
    currentVote: vote,
  );

  /// `https://www.example.com/a` → `example.com`.
  static String hostOf(String? url) {
    if (url == null) return '';
    final host = Uri.tryParse(url)?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  static int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  @override
  String toString() => 'Post($id, $title)';
}
