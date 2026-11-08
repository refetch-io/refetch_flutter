import 'package:appwrite/appwrite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refetch/core/network/api_exception.dart';
import 'package:refetch/core/network/error_message.dart';

void main() {
  test('surfaces ApiException message', () {
    expect(messageForError(const ApiException(400, 'Bad input')), 'Bad input');
  });

  test('surfaces AppwriteException message (the real auth reason)', () {
    final error = AppwriteException(
      'Invalid credentials. Please check the email and password.',
      401,
      'user_invalid_credentials',
    );
    expect(
      messageForError(error, fallback: 'Sign in failed.'),
      'Invalid credentials. Please check the email and password.',
    );
  });

  test('uses fallback when AppwriteException has no message', () {
    expect(
      messageForError(AppwriteException(), fallback: 'Sign in failed.'),
      'Sign in failed.',
    );
  });

  test('uses fallback for unknown errors', () {
    expect(messageForError(Exception('x'), fallback: 'Nope'), 'Nope');
    expect(messageForError(null, fallback: 'Nope'), 'Nope');
  });

  test('uses fallback when ApiException message is blank', () {
    expect(
      messageForError(const ApiException(400, '   '), fallback: 'Oops'),
      'Oops',
    );
  });

  test('a blank 5xx body still explains itself rather than falling back', () {
    // 5xx bodies are often empty or an HTML error page, so the caller's
    // generic fallback is less useful than naming the server as the cause.
    expect(
      messageForError(const ApiException(500, '   '), fallback: 'Oops'),
      'Refetch is having trouble right now. Please try again shortly.',
    );
  });

  test('explains a transport failure instead of leaking SocketException', () {
    const error = ApiException(
      0,
      "Network error: SocketException: Failed host lookup: 'refetch.io'",
    );
    expect(
      messageForError(error),
      "Can't reach Refetch. Check your connection and try again.",
    );
    expect(
      detailForError(error),
      "SocketException: Failed host lookup: 'refetch.io'",
    );
  });

  test('treats 5xx as a server problem worth retrying', () {
    const error = ApiException(503, 'upstream unavailable');
    expect(
      messageForError(error),
      'Refetch is having trouble right now. Please try again shortly.',
    );
    expect(detailForError(error), 'HTTP 503');
  });

  test('still surfaces actionable 4xx messages verbatim', () {
    const error = ApiException(422, 'That URL was already submitted.');
    expect(messageForError(error), 'That URL was already submitted.');
    expect(detailForError(error), 'HTTP 422');
  });

  group('Appwrite read failures', () {
    final offline = AppwriteException(
      'ClientException with SocketException: Failed host lookup: '
      "'fra.cloud.appwrite.io' (OS Error: No address associated with hostname, errno = 7), "
      'uri=https://fra.cloud.appwrite.io/v1/tablesdb/x',
    );

    test('a transport failure reads as offline, not as socket text', () {
      expect(
        messageForError(offline),
        "Can't reach Refetch. Check your connection and try again.",
      );
      expect(errorKind(offline), 'network');
      expect(
        detailForError(offline),
        startsWith('SocketException: Failed host lookup'),
      );
    });

    test('5xx reads as a server problem; 4xx keeps the message', () {
      final server = AppwriteException('Server Error', 503, 'general_unknown');
      final missing = AppwriteException('Row not found', 404, 'row_not_found');
      expect(errorKind(server), 'server');
      expect(messageForError(server), startsWith('Refetch is having trouble'));
      expect(errorKind(missing), 'client');
      expect(messageForError(missing), 'Row not found');
      expect(detailForError(missing), 'Appwrite 404 row_not_found');
    });

    test('a code-less SDK error that is not transport keeps its message', () {
      final local = AppwriteException('Missing required parameter: "rowId"');
      expect(errorKind(local), 'client');
      expect(messageForError(local), 'Missing required parameter: "rowId"');
    });
  });
}
