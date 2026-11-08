import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/analytics/analytics_providers.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/network/error_message.dart';
import '../../../core/share/share_story.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/site_favicon.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../feed/domain/post.dart';
import '../../feed/presentation/post_card.dart' show openArticle;
import '../../vote/presentation/vote_buttons.dart';
import '../data/thread_repository.dart';
import '../domain/comment.dart';
import 'comment_tile.dart';
import 'thread_controller.dart';

/// A story with its comment thread and a comment composer.
class ThreadScreen extends ConsumerWidget {
  const ThreadScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(threadProvider(postId));
    final user = ref.watch(currentUserProvider);

    ref.listen(threadProvider(postId), (previous, next) {
      if (next.hasError && !next.isLoading) {
        ref
            .read(analyticsProvider)
            .track(
              AnalyticsEvents.threadLoadFailed,
              props: {'post_id': postId, 'reason': errorKind(next.error)},
            );
      }
    });

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (async.value case final thread?)
            Builder(
              builder: (buttonContext) => IconButton(
                tooltip: 'Share',
                icon: const Icon(LucideIcons.share, size: 22),
                onPressed: () => shareStory(
                  buttonContext,
                  ref,
                  thread.post,
                  source: 'thread',
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: async.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => _composeComment(context, ref, user: user),
              icon: const Icon(LucideIcons.messageCircle, size: 20),
              label: const Text('Comment'),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: errorKind(error) == 'network'
              ? LucideIcons.wifiOff
              : LucideIcons.circleAlert,
          title: "Couldn't load this story",
          message: messageForError(
            error,
            fallback: 'Something went wrong. Please try again.',
          ),
          detail: kDebugMode ? detailForError(error) : null,
          action: OutlinedButton(
            onPressed: () => ref.invalidate(threadProvider(postId)),
            child: const Text('Try again'),
          ),
        ),
        data: (thread) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(threadProvider(postId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
            children: [
              Card(child: _PostHeader(post: thread.post)),
              const SizedBox(height: 20),
              _CommentsSection(
                comments: thread.comments,
                total: thread.commentCount,
                onReply: (parent) =>
                    _composeComment(context, ref, user: user, parent: parent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _composeComment(
    BuildContext context,
    WidgetRef ref, {
    required AppUser? user,
    Comment? parent,
  }) async {
    if (user == null) {
      context.push('/signin');
      return;
    }

    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CommentComposer(replyingTo: parent?.author),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(threadRepositoryProvider)
          .addComment(postId: postId, text: text.trim(), replyId: parent?.id);
      ref
          .read(analyticsProvider)
          .track(
            AnalyticsEvents.commentPosted,
            props: {'post_id': postId, 'is_reply': parent != null},
          );
      ref.invalidate(threadProvider(postId));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            messageForError(error, fallback: 'Could not post your comment.'),
          ),
        ),
      );
    }
  }
}

class _PostHeader extends ConsumerWidget {
  const _PostHeader({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.colors;

    final meta = [
      'by ${post.author}',
      if (post.timeAgo != null) post.timeAgo!,
      if (post.readingTime != null) '${post.readingTime} min read',
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VoteButtons(
                resourceId: post.id,
                resourceType: 'post',
                fallbackCount: post.count,
                fallbackVote: post.currentVote,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.domain.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SiteFavicon(
                              domain: post.link ?? post.domain,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                post.domain,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: c.brandText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(post.title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(meta, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (post.tldr != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.brandTint,
                borderRadius: BorderRadius.circular(AppTheme.controlRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // DESIGN.md: label AI-generated content in words.
                  Text(
                    'Summary, generated by AI',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: c.brandText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(post.tldr!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
          if (post.description != null && post.tldr == null) ...[
            const SizedBox(height: 16),
            Text(post.description!, style: theme.textTheme.bodyMedium),
          ],
          if (post.link != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    openArticle(context, ref, post, source: 'thread'),
                icon: const Icon(LucideIcons.externalLink, size: 18),
                label: const Text('Read article'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.comments,
    required this.total,
    required this.onReply,
  });

  final List<Comment> comments;
  final int total;
  final void Function(Comment parent) onReply;

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: EmptyState(
          icon: LucideIcons.messagesSquare,
          title: 'No comments yet',
          message: 'Start the conversation.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            '$total ${total == 1 ? 'comment' : 'comments'}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final comment in comments)
                  CommentTile(comment: comment, onReply: onReply),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentComposer extends StatefulWidget {
  const _CommentComposer({this.replyingTo});

  final String? replyingTo;

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.replyingTo == null
                ? 'Add a comment'
                : 'Reply to ${widget.replyingTo}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(hintText: 'What do you think?'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }
}
