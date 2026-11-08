import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/vote_state.dart';

/// A resource to look up a vote for: a post or a comment.
typedef VoteResource = ({String id, String type});

/// Casts votes and reads the signed-in person's votes through the app API
/// (`/api/app/vote`, `/api/app/votes`). Votes are private, so they can't be
/// read from Appwrite directly.
class VoteRepository {
  VoteRepository(this._api);

  final ApiClient _api;

  /// Casts, flips or removes a vote ([voteType] again removes it). The server
  /// answers the resulting score and vote.
  Future<VoteState> vote({
    required String resourceId,
    required String resourceType,
    required String voteType,
  }) async {
    final data =
        await _api.post(
              '/api/app/vote',
              body: {
                'resourceType': resourceType,
                'resourceId': resourceId,
                'direction': voteType,
              },
            )
            as Map<String, dynamic>;

    return VoteState(
      count: data['count'] is num ? (data['count'] as num).toInt() : 0,
      currentVote: data['vote'] as String?,
    );
  }

  /// The signed-in person's votes on many resources at once: id → `'up'` or
  /// `'down'`. Resources without a vote are left out.
  Future<Map<String, String>> batch(List<VoteResource> resources) async {
    if (resources.isEmpty) return const {};

    final data =
        await _api.post(
              '/api/app/votes',
              body: {
                'posts': [
                  for (final r in resources)
                    if (r.type == 'post') r.id,
                ],
                'comments': [
                  for (final r in resources)
                    if (r.type == 'comment') r.id,
                ],
              },
            )
            as Map<String, dynamic>;

    return {
      for (final group in ['posts', 'comments'])
        if (data[group] is Map)
          for (final entry in (data[group] as Map).entries)
            if (entry.value is String) '${entry.key}': entry.value as String,
    };
  }
}

final voteRepositoryProvider = Provider<VoteRepository>((ref) {
  return VoteRepository(ref.watch(apiClientProvider));
});
