import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:refetch/core/network/api_client.dart';
import 'package:refetch/features/vote/data/vote_repository.dart';

class _MockApi extends Mock implements ApiClient {}

void main() {
  late _MockApi api;
  late VoteRepository repo;

  setUp(() {
    api = _MockApi();
    repo = VoteRepository(api);
  });

  test('vote sends direction and reads the new vote and score', () async {
    when(
      () => api.post('/api/app/vote', body: any(named: 'body')),
    ).thenAnswer((_) async => {'vote': null, 'count': 9});

    final state = await repo.vote(
      resourceId: 'p1',
      resourceType: 'post',
      voteType: 'up',
    );

    expect(state.count, 9);
    expect(state.currentVote, isNull);
    final body = verify(
      () => api.post('/api/app/vote', body: captureAny(named: 'body')),
    ).captured.single;
    expect(body, {
      'resourceType': 'post',
      'resourceId': 'p1',
      'direction': 'up',
    });
  });

  test('batch splits posts and comments and merges the answer', () async {
    when(() => api.post('/api/app/votes', body: any(named: 'body'))).thenAnswer(
      (_) async => {
        'posts': {'p1': 'up'},
        'comments': {'c1': 'down'},
      },
    );

    final votes = await repo.batch([
      (id: 'p1', type: 'post'),
      (id: 'p2', type: 'post'),
      (id: 'c1', type: 'comment'),
    ]);

    expect(votes, {'p1': 'up', 'c1': 'down'});
    final body = verify(
      () => api.post('/api/app/votes', body: captureAny(named: 'body')),
    ).captured.single;
    expect(body, {
      'posts': ['p1', 'p2'],
      'comments': ['c1'],
    });
  });

  test('batch with nothing to look up makes no request', () async {
    expect(await repo.batch(const []), isEmpty);
    verifyNever(() => api.post(any(), body: any(named: 'body')));
  });
}
