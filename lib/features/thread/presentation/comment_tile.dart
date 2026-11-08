import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

import '../../vote/presentation/vote_buttons.dart';
import '../domain/comment.dart';

/// Renders a comment and (recursively) its replies, indented by depth.
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.onReply,
    this.depth = 0,
  });

  final Comment comment;
  final void Function(Comment parent) onReply;
  final int depth;

  static const double _indentPerLevel = 14;
  static const int _maxIndentLevels = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indent = _indentPerLevel * (depth.clamp(0, _maxIndentLevels));

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            decoration: BoxDecoration(
              border: depth > 0
                  ? Border(
                      left: BorderSide(
                        color: context.colors.separator,
                        width: 2,
                      ),
                    )
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VoteButtons(
                  resourceId: comment.id,
                  resourceType: 'comment',
                  fallbackCount: comment.count,
                  fallbackVote: comment.currentVote,
                  compact: true,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            comment.author,
                            style: theme.textTheme.labelMedium,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            comment.timeAgo,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(comment.text, style: theme.textTheme.bodyMedium),
                      TextButton.icon(
                        onPressed: () => onReply(comment),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 32),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(LucideIcons.reply, size: 15),
                        label: const Text('Reply'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final reply in comment.replies)
            CommentTile(comment: reply, onReply: onReply, depth: depth + 1),
        ],
      ),
    );
  }
}
