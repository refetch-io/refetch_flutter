/// The current user's vote and the aggregate score for a single resource
/// (a post or a comment).
class VoteState {
  const VoteState({required this.count, this.currentVote});

  /// Aggregate score (`count` on the post/comment).
  final int count;

  /// `'up'`, `'down'`, or `null`.
  final String? currentVote;

  bool get isUp => currentVote == 'up';
  bool get isDown => currentVote == 'down';

  VoteState copyWith({int? count, String? currentVote, bool clearVote = false}) {
    return VoteState(
      count: count ?? this.count,
      currentVote: clearVote ? null : (currentVote ?? this.currentVote),
    );
  }

  factory VoteState.fromJson(Map<String, dynamic> json) {
    return VoteState(
      count: json['count'] is num ? (json['count'] as num).toInt() : 0,
      currentVote: json['currentVote'] as String?,
    );
  }
}
