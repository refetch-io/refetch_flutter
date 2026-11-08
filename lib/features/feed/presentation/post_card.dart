import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/analytics/analytics_providers.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/share/share_story.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/site_favicon.dart';
import '../../vote/presentation/vote_buttons.dart';
import '../domain/post.dart';

/// One story row in a feed list (refetch.io `PostRow`): optional rank, vote
/// control, favicon, title, and a meta line with comments and share. Tapping
/// opens the thread, whose "Read article" opens the link.
class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    this.rank,
    this.source = 'feed',
  });

  final Post post;

  /// 1-based position where order means something (Top, Show).
  final int? rank;

  /// Where the row is shown, for analytics (`feed_top`, `feed_new`, …).
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.colors;

    return InkWell(
      onTap: () {
        ref
            .read(analyticsProvider)
            .track(
              AnalyticsEvents.storyOpened,
              props: {'post_id': post.id, 'source': source},
            );
        context.push('/thread/${post.id}');
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rank != null)
              SizedBox(
                width: 24,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: rank! <= 3 ? c.brandText : c.labelQuaternary,
                    ),
                  ),
                ),
              ),
            VoteButtons(
              resourceId: post.id,
              resourceType: 'post',
              fallbackCount: post.count,
              fallbackVote: post.currentVote,
              compact: true,
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SiteFavicon(domain: post.link ?? post.domain, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _MetaLine(post: post, source: source),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

/// Opens the story's article in the browser and records it.
Future<void> openArticle(
  BuildContext context,
  WidgetRef ref,
  Post post, {
  required String source,
}) async {
  final uri = post.link == null ? null : Uri.tryParse(post.link!);
  final messenger = ScaffoldMessenger.of(context);
  ref
      .read(analyticsProvider)
      .track(
        AnalyticsEvents.articleOpened,
        props: {'post_id': post.id, 'source': source, 'domain': post.domain},
      );
  if (uri == null ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open the link.')),
    );
  }
}

class _MetaLine extends ConsumerWidget {
  const _MetaLine({required this.post, required this.source});

  final Post post;
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: c.labelTertiary);

    final parts = <String>[
      if (post.domain.isNotEmpty) post.domain,
      if (post.timeAgo != null) post.timeAgo!,
    ];

    return Row(
      children: [
        Flexible(
          child: Text(
            parts.join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: 10),
        Icon(LucideIcons.messageCircle, size: 13, color: c.labelTertiary),
        const SizedBox(width: 4),
        Text(
          '${post.countComments}',
          style: style?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 4),
        Builder(
          builder: (buttonContext) => IconButton(
            tooltip: 'Share',
            visualDensity: VisualDensity.compact,
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 24),
            icon: Icon(LucideIcons.share, size: 15, color: c.labelTertiary),
            onPressed: () =>
                shareStory(buttonContext, ref, post, source: source),
          ),
        ),
      ],
    );
  }
}
