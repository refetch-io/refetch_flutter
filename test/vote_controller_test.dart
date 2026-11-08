import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refetch/features/vote/data/vote_repository.dart';
import 'package:refetch/features/vote/domain/vote_state.dart';
import 'package:refetch/features/vote/presentation/vote_controller.dart';

class _FakeVoteRepository implements VoteRepository {
  _FakeVoteRepository(this.result, {this.shouldThrow = false});

  VoteState result;
  bool shouldThrow;
  int voteCalls = 0;

  @override
  Future<VoteState> vote({
    required String resourceId,
    required String resourceType,
    required String voteType,
  }) async {
    voteCalls++;
    if (shouldThrow) throw Exception('boom');
    return result;
  }

  @override
  Future<Map<String, String>> batch(List<VoteResource> resources) async =>
      const {};
}

ProviderContainer _containerWith(VoteRepository repo) {
  final container = ProviderContainer(
    overrides: [voteRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  const fallback = VoteState(count: 10, currentVote: null);

  test('optimistic upvote increments immediately, then reconciles', () async {
    final repo = _FakeVoteRepository(
      const VoteState(count: 11, currentVote: 'up'),
    );
    final container = _containerWith(repo);
    final controller = container.read(voteControllerProvider.notifier);

    final future = controller.vote(
      resourceId: 'p1',
      resourceType: 'post',
      voteType: 'up',
      fallback: fallback,
    );

    // Optimistic state applied synchronously before the await resolves.
    expect(container.read(voteControllerProvider)['p1']!.count, 11);
    expect(container.read(voteControllerProvider)['p1']!.currentVote, 'up');

    await future;
    expect(container.read(voteControllerProvider)['p1']!.count, 11);
    expect(repo.voteCalls, 1);
  });

  test('toggling the same direction removes the vote', () async {
    final repo = _FakeVoteRepository(const VoteState(count: 10));
    final container = _containerWith(repo);
    final controller = container.read(voteControllerProvider.notifier);

    await controller.vote(
      resourceId: 'p1',
      resourceType: 'post',
      voteType: 'up',
      fallback: const VoteState(count: 11, currentVote: 'up'),
    );

    // Server returns the post-toggle state (no current vote).
    expect(container.read(voteControllerProvider)['p1']!.currentVote, isNull);
  });

  test('rolls back to the previous state when the request fails', () async {
    final repo = _FakeVoteRepository(
      const VoteState(count: 0),
      shouldThrow: true,
    );
    final container = _containerWith(repo);
    final controller = container.read(voteControllerProvider.notifier);

    await expectLater(
      controller.vote(
        resourceId: 'p1',
        resourceType: 'post',
        voteType: 'down',
        fallback: fallback,
      ),
      throwsException,
    );

    final state = container.read(voteControllerProvider)['p1']!;
    expect(state.count, fallback.count);
    expect(state.currentVote, fallback.currentVote);
  });
}
