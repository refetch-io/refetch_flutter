import 'package:flutter_test/flutter_test.dart';
import 'package:refetch/features/feed/domain/post.dart';

void main() {
  group('Post.fromRow', () {
    test('maps a posts-table row', () {
      final post = Post.fromRow({
        r'$id': 'abc',
        r'$createdAt': '2026-11-08T08:00:00.000+00:00',
        'title': 'Hello',
        'description': '  A note  ',
        'userId': 'u1',
        'userName': 'jane',
        'count': 42,
        'countComments': 7,
        'link': 'https://www.example.com/x',
        'type': 'link',
        'readingTime': 5,
        'tldr': 'Short summary',
      }, currentVote: 'up');

      expect(post.id, 'abc');
      expect(post.title, 'Hello');
      expect(post.domain, 'example.com');
      expect(post.count, 42);
      expect(post.countComments, 7);
      expect(post.author, 'jane');
      expect(post.description, 'A note');
      expect(post.tldr, 'Short summary');
      expect(post.readingTime, 5);
      expect(post.currentVote, 'up');
      expect(post.createdAt, DateTime.utc(2026, 11, 8, 8));
      expect(post.isShow, isFalse);
      expect(post.threadUrl, 'https://refetch.io/threads/abc');
    });

    test('applies the web defaults to a sparse row', () {
      final post = Post.fromRow({r'$id': 'only-id'});
      expect(post.title, '');
      expect(post.count, 0);
      expect(post.countComments, 0);
      expect(post.author, 'Anonymous');
      expect(post.domain, '');
      expect(post.link, isNull);
      expect(post.readingTime, isNull);
      expect(post.description, isNull);
      expect(post.timeAgo, isNull);
      expect(post.type, 'link');
    });

    test('drops non-http links and empty summaries, keeps show posts', () {
      final post = Post.fromRow({
        r'$id': 'x',
        'link': 'javascript:alert(1)',
        'tldr': '   ',
        'readingTime': 0,
        'type': 'show',
      });
      expect(post.link, isNull);
      expect(post.domain, '');
      expect(post.tldr, isNull);
      expect(post.readingTime, isNull);
      expect(post.isShow, isTrue);
    });

    test('withVote replaces only the vote', () {
      final post = Post.fromRow({r'$id': 'a', 'count': 3}, currentVote: 'up');
      final cleared = post.withVote(null);
      expect(cleared.currentVote, isNull);
      expect(cleared.count, 3);
      expect(cleared.id, 'a');
    });
  });

  test('hostOf strips www and tolerates junk', () {
    expect(Post.hostOf('https://www.theverge.com/a'), 'theverge.com');
    expect(Post.hostOf('https://news.ycombinator.com'), 'news.ycombinator.com');
    expect(Post.hostOf(null), '');
    expect(Post.hostOf('not a url'), '');
  });
}
