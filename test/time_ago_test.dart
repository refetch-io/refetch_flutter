import 'package:flutter_test/flutter_test.dart';
import 'package:refetch/core/format/time_ago.dart';

void main() {
  final now = DateTime(2026, 11, 8, 12);

  test('reads like refetch.io', () {
    expect(
      timeAgo(now.subtract(const Duration(seconds: 20)), now: now),
      'just now',
    );
    expect(
      timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
      '5m ago',
    );
    expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
    expect(timeAgo(now.subtract(const Duration(days: 2)), now: now), '2d ago');
    expect(timeAgo(DateTime(2026, 8, 3), now: now), 'Aug 3');
    expect(timeAgo(DateTime(2025, 8, 3), now: now), 'Aug 3, 2025');
  });

  test('a clock running behind does not show a negative age', () {
    expect(timeAgo(now.add(const Duration(minutes: 2)), now: now), 'just now');
  });
}
