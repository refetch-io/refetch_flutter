import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/analytics/analytics_providers.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/network/error_message.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/vote_state.dart';
import 'vote_controller.dart';

/// Up/down vote control with the score between, for a post or comment.
///
/// Reads live state from [voteControllerProvider], falling back to the
/// resource's own [fallbackCount] / [fallbackVote] when not yet tracked.
class VoteButtons extends ConsumerWidget {
  const VoteButtons({
    super.key,
    required this.resourceId,
    required this.resourceType,
    required this.fallbackCount,
    this.fallbackVote,
    this.compact = false,
  });

  final String resourceId;
  final String resourceType; // 'post' | 'comment'
  final int fallbackCount;
  final String? fallbackVote;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final votes = ref.watch(voteControllerProvider);
    final fallback = VoteState(count: fallbackCount, currentVote: fallbackVote);
    final state = votes[resourceId] ?? fallback;
    final c = context.colors;
    final size = compact ? 16.0 : 20.0;
    final countColor = state.isUp
        ? c.up
        : state.isDown
        ? c.down
        : c.labelSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _VoteIcon(
          icon: LucideIcons.arrowUp,
          tooltip: state.isUp ? 'Remove upvote' : 'Upvote',
          size: size,
          color: state.isUp ? c.up : c.labelTertiary,
          tint: state.isUp ? c.upTint : null,
          onTap: () => _vote(context, ref, 'up', fallback),
        ),
        Text(
          '${state.count}',
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: countColor,
          ),
        ),
        _VoteIcon(
          icon: LucideIcons.arrowDown,
          tooltip: state.isDown ? 'Remove downvote' : 'Downvote',
          size: size,
          color: state.isDown ? c.down : c.labelTertiary,
          tint: state.isDown ? c.downTint : null,
          onTap: () => _vote(context, ref, 'down', fallback),
        ),
      ],
    );
  }

  Future<void> _vote(
    BuildContext context,
    WidgetRef ref,
    String direction,
    VoteState fallback,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.push('/signin');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final analytics = ref.read(analyticsProvider);
    try {
      await ref
          .read(voteControllerProvider.notifier)
          .vote(
            resourceId: resourceId,
            resourceType: resourceType,
            voteType: direction,
            fallback: fallback,
          );
      analytics.track(
        AnalyticsEvents.voteCast,
        props: {'resource_type': resourceType, 'direction': direction},
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            messageForError(error, fallback: 'Could not register your vote.'),
          ),
        ),
      );
    }
  }
}

class _VoteIcon extends StatelessWidget {
  const _VoteIcon({
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.color,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final String tooltip;
  final double size;
  final Color color;
  final Color? tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final box = size + 14;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: tint ?? Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: box,
            height: box,
            child: Icon(icon, size: size, color: color),
          ),
        ),
      ),
    );
  }
}
