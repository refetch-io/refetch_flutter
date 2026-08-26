import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/error_message.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../vote/data/vote_repository.dart';
import '../../vote/presentation/vote_controller.dart';
import '../data/feed_repository.dart';
import '../domain/post.dart';
import 'post_card.dart';

/// A paginated, pull-to-refresh list for a single [FeedTab].
///
/// Pagination state lives in this widget (rather than a Riverpod family) so each
/// tab keeps its own scroll position and page cursor while staying alive across
/// tab switches.
class FeedList extends ConsumerStatefulWidget {
  const FeedList({super.key, required this.tab});

  final FeedTab tab;

  @override
  ConsumerState<FeedList> createState() => _FeedListState();
}

class _FeedListState extends ConsumerState<FeedList>
    with AutomaticKeepAliveClientMixin {
  final List<Post> _posts = [];
  final ScrollController _scrollController = ScrollController();

  int _offset = 0;
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;
  bool _initialLoadDone = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await ref
          .read(feedRepositoryProvider)
          .fetch(
            widget.tab,
            limit: AppConfig.feedPageSize,
            offset: _offset,
          );
      if (!mounted) return;
      setState(() {
        _posts.addAll(page);
        _offset += page.length;
        _hasMore = page.length == AppConfig.feedPageSize;
        _loading = false;
        _initialLoadDone = true;
      });
      _primeVotes(page);
    } catch (error) {
      // Also logged so a failure is recoverable from device logs when someone
      // reports it, not only from what happens to be on screen.
      debugPrint('Feed load failed (${widget.tab.name}): $error');
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
        _initialLoadDone = true;
      });
    }
  }

  /// Loads the signed-in user's vote state for the freshly loaded page so the
  /// arrows render in the correct (already-voted) state.
  Future<void> _primeVotes(List<Post> page) async {
    if (page.isEmpty || ref.read(currentUserProvider) == null) return;
    try {
      final resources = <VoteResource>[
        for (final p in page) (id: p.id, type: 'post'),
      ];
      final votes = await ref.read(voteRepositoryProvider).batch(resources);
      if (!mounted) return;
      ref.read(voteControllerProvider.notifier).prime(votes);
    } catch (_) {
      // Vote priming is best-effort; arrows fall back to default state.
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _posts.clear();
      _offset = 0;
      _hasMore = true;
      _error = null;
      _initialLoadDone = false;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.tab.requiresAuth && ref.watch(currentUserProvider) == null) {
      return _SignInPrompt(onSignIn: () => context.push('/signin'));
    }

    if (!_initialLoadDone && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _posts.isEmpty) {
      return _ErrorState(error: _error, onRetry: _refresh);
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: const [
            SizedBox(height: 200),
            Center(child: Text('Nothing here yet.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        itemCount: _posts.length + 1,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _posts.length) {
            return _FooterLoader(loading: _loading, hasMore: _hasMore);
          }
          return PostCard(post: _posts[index]);
        },
      ),
    );
  }
}

class _FooterLoader extends StatelessWidget {
  const _FooterLoader({required this.loading, required this.hasMore});

  final bool loading;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            "You've reached the end.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    return const SizedBox(height: 48);
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 48),
          const SizedBox(height: 12),
          const Text('Sign in to see your posts.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onSignIn, child: const Text('Sign in')),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Debug builds only: the friendly message already separates "offline" from
    // "server broke" from a real API message, so users gain nothing from an
    // exception class name — and release notes of it read as an unfinished app.
    final detail = kDebugMode ? detailForError(error) : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              messageForError(error, fallback: 'Could not load the feed.'),
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              // Shown so someone reporting a problem can quote something more
              // specific than "it didn't load".
              Text(
                detail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
