import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/appwrite/appwrite_providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../feed/data/feed_repository.dart';
import '../../feed/domain/post.dart';
import '../../vote/data/vote_repository.dart';
import '../domain/comment.dart';

/// A post together with its (nested) comment tree.
class ThreadData {
  const ThreadData({required this.post, required this.comments});

  final Post post;
  final List<Comment> comments;

  /// Every comment, replies included.
  int get commentCount => Comment.flatten(comments).length;
}

/// The most comments a thread loads (the web's `MAX_THREAD_COMMENTS`).
const maxThreadComments = 500;

/// Reads a thread from Appwrite (posts and comments are public-read) and
/// writes comments through the app API.
class ThreadRepository {
  ThreadRepository(this._tables, this._feed, this._api, this._votes);

  final TablesDB _tables;
  final FeedRepository _feed;
  final ApiClient _api;
  final VoteRepository _votes;

  /// Loads the story and its comments; when [signedIn], also the viewer's
  /// votes on them (best effort).
  Future<ThreadData> load(String postId, {bool signedIn = false}) async {
    var (post, list) = await (
      _feed.get(postId),
      _tables.listRows(
        databaseId: AppConfig.databaseId,
        tableId: AppConfig.commentsTableId,
        queries: [
          Query.equal('postId', postId),
          Query.orderDesc(r'$createdAt'),
          Query.limit(maxThreadComments),
          Query.select(Comment.fields),
        ],
        total: false,
      ),
    ).wait;
    final flat = [for (final row in list.rows) Comment.fromRow(row.data)];

    var votes = const <String, String>{};
    if (signedIn) {
      try {
        votes = await _votes.batch([
          (id: post.id, type: 'post'),
          for (final c in flat) (id: c.id, type: 'comment'),
        ]);
      } catch (_) {
        // Arrows fall back to "not voted".
      }
      post = post.withVote(votes[post.id]);
    }

    return ThreadData(
      post: post,
      comments: Comment.buildTree(flat, votes: votes),
    );
  }

  Future<void> addComment({
    required String postId,
    required String text,
    String? replyId,
  }) async {
    await _api.post(
      '/api/app/comments',
      body: {'postId': postId, 'content': text, 'replyId': ?replyId},
    );
  }

  Future<void> deleteComment(String commentId) async {
    await _api.delete('/api/app/comments/$commentId');
  }
}

final threadRepositoryProvider = Provider<ThreadRepository>((ref) {
  return ThreadRepository(
    ref.watch(tablesDbProvider),
    ref.watch(feedRepositoryProvider),
    ref.watch(apiClientProvider),
    ref.watch(voteRepositoryProvider),
  );
});
