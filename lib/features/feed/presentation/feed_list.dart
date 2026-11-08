import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/analytics/analytics_providers.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/error_message.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../vote/data/vote_repository.dart';
import '../../vote/domain/vote_state.dart';
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
            userId: ref.read(currentUserProvider)?.id,
          );
      ref
          .read(analyticsProvider)
          .track(
            AnalyticsEvents.feedLoaded,
            props: {
              'tab': widget.tab.analyticsName,
              'page': _offset ~/ AppConfig.feedPageSize + 1,
              'count': page.length,
            },
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
      ref
          .read(analyticsProvider)
          .track(
            AnalyticsEvents.feedLoadFailed,
            props: {
              'tab': widget.tab.analyticsName,
              'page': _offset ~/ AppConfig.feedPageSize + 1,
              'reason': errorKind(error),
            },
          );
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
      ref.read(voteControllerProvider.notifier).prime({
        for (final p in page)
          if (votes[p.id] != null)
            p.id: VoteState(count: p.count, currentVote: votes[p.id]),
      });
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
      return EmptyState(
        icon: LucideIcons.lock,
        title: 'Your stories live here',
        message: 'Sign in to see the stories you have shared.',
        action: FilledButton(
          onPressed: () => context.push('/signin'),
          child: const Text('Sign in'),
        ),
      );
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
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: widget.tab == FeedTab.mines
                  ? EmptyState(
                      icon: LucideIcons.squarePen,
                      title: 'Nothing shared yet',
                      message: 'Stories you submit will show up here.',
                      action: FilledButton(
                        onPressed: () => context.push('/submit'),
                        child: const Text('Submit a story'),
                      ),
                    )
                  : const EmptyState(
                      icon: LucideIcons.newspaper,
                      title: 'No stories right now',
                      message: 'Pull down to check again in a bit.',
                    ),
            ),
          ),
        ),
      );
    }

    final ranked = widget.tab == FeedTab.top || widget.tab == FeedTab.show;
    final c = context.colors;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: _posts.length + 1,
        itemBuilder: (context, index) {
          if (index >= _posts.length) {
            return _FooterLoader(loading: _loading, hasMore: _hasMore);
          }
          // One rounded card for the whole list, with hairlines between rows
          // (refetch.io's inset grouped list).
          final first = index == 0;
          final last = index == _posts.length - 1;
          const r = Radius.circular(AppTheme.cardRadius);
          return Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.vertical(
                top: first ? r : Radius.zero,
                bottom: last ? r : Radius.zero,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                PostCard(
                  post: _posts[index],
                  rank: ranked ? index + 1 : null,
                  source: 'feed_${widget.tab.analyticsName}',
                ),
                if (!last)
                  Padding(
                    padding: EdgeInsets.only(left: ranked ? 70 : 46),
                    child: const Divider(height: 0.5),
                  ),
              ],
            ),
          );
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
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            "You're all caught up.",
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      );
    }
    return const SizedBox(height: 48);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final kind = errorKind(error);
    return EmptyState(
      icon: kind == 'network' ? LucideIcons.wifiOff : LucideIcons.circleAlert,
      title: kind == 'network' ? "You're offline" : "Couldn't load stories",
      message: messageForError(
        error,
        fallback: 'Something went wrong. Please try again.',
      ),
      // Debug builds only: the friendly message already separates "offline"
      // from "server broke"; users gain nothing from an exception name.
      detail: kDebugMode ? detailForError(error) : null,
      action: OutlinedButton(
        onPressed: onRetry,
        child: const Text('Try again'),
      ),
    );
  }
}
