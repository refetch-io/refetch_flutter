import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:refetch/features/feed/data/feed_repository.dart';

/// Decodes the query strings so the test reads as data, not JSON.
List<Map<String, dynamic>> _decode(List<String> queries) => [
  for (final q in queries) jsonDecode(q) as Map<String, dynamic>,
];

Map<String, dynamic>? _find(
  List<Map<String, dynamic>> qs,
  String method, [
  String? attribute,
]) {
  for (final q in qs) {
    if (q['method'] == method &&
        (attribute == null || q['attribute'] == attribute)) {
      return q;
    }
  }
  return null;
}

void main() {
  final now = DateTime.utc(2026, 11, 8, 12);

  test('Top mirrors the web front page: last 24h, quality gates, by score', () {
    final qs = _decode(
      feedQueries(FeedTab.top, limit: 25, offset: 50, now: now),
    );

    expect(_find(qs, 'greaterThan', r'$createdAt')!['values'], [
      '2026-11-07T12:00:00.000Z',
    ]);
    expect(_find(qs, 'lessThan', 'spamScore')!['values'], [70]);
    expect(_find(qs, 'greaterThan', 'relevancyScore')!['values'], [30]);
    expect(_find(qs, 'equal', 'enhanced')!['values'], [true]);
    expect(
      qs.where((q) => q['method'] == 'orderDesc').map((q) => q['attribute']),
      ['score', r'$createdAt'],
    );
    expect(_find(qs, 'limit')!['values'], [25]);
    expect(_find(qs, 'offset')!['values'], [50]);
    expect(_find(qs, 'equal', 'type'), isNull);
  });

  test('New orders by time only', () {
    final qs = _decode(
      feedQueries(FeedTab.latest, limit: 25, offset: 0, now: now),
    );
    expect(
      qs.where((q) => q['method'] == 'orderDesc').map((q) => q['attribute']),
      [r'$createdAt'],
    );
  });

  test('Show filters to show posts', () {
    final qs = _decode(
      feedQueries(FeedTab.show, limit: 25, offset: 0, now: now),
    );
    expect(_find(qs, 'equal', 'type')!['values'], ['show']);
  });

  test(
    'Mines lists the signed-in person\'s stories, newest first, ungated',
    () {
      final qs = _decode(
        feedQueries(FeedTab.mines, limit: 25, offset: 0, userId: 'u1'),
      );
      expect(_find(qs, 'equal', 'userId')!['values'], ['u1']);
      expect(_find(qs, 'lessThan', 'spamScore'), isNull);
      expect(_find(qs, 'orderDesc')!['attribute'], r'$createdAt');
    },
  );
}
