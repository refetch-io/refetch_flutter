import 'package:appwrite/appwrite.dart';

import 'api_exception.dart';

/// Extracts a human-readable message from any error raised by the app's two
/// backends:
///  * [ApiException] — from the refetch.io app API client (writes).
///  * [AppwriteException] — from the Appwrite SDK (reads, auth, push targets).
///
/// Falls back to [fallback] only when no useful message is available, so the
/// user sees the real reason (e.g. "Invalid credentials") instead of a generic
/// failure string.
String messageForError(
  Object? error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is ApiException) {
    // Transport failures carry text like "SocketException: Failed host lookup",
    // which reads as a crash rather than an explanation. Say what it means
    // instead; the raw text stays on the exception for [detailForError].
    if (error.isNetworkFailure) {
      return "Can't reach Refetch. Check your connection and try again.";
    }
    if (error.isServerError) {
      return 'Refetch is having trouble right now. Please try again shortly.';
    }
    return error.message.trim().isNotEmpty ? error.message : fallback;
  }
  if (error is AppwriteException) {
    // The SDK wraps transport failures (no network, DNS, TLS) in an
    // exception with no status code and the raw socket text as its message.
    if (_isAppwriteTransport(error)) {
      return "Can't reach Refetch. Check your connection and try again.";
    }
    if ((error.code ?? 0) >= 500) {
      return 'Refetch is having trouble right now. Please try again shortly.';
    }
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) return message;
  }
  return fallback;
}

/// The SDK rethrows transport failures as `AppwriteException(e.toString())`:
/// no status code, and the socket/HTTP-client error text as the message.
bool _isAppwriteTransport(AppwriteException error) {
  if (error.code != null && error.code != 0) return false;
  final message = error.message ?? '';
  return RegExp(
    'SocketException|ClientException|HandshakeException|TimeoutException|'
    'Failed host lookup|Connection (refused|reset|closed)|Network is unreachable',
  ).hasMatch(message);
}

/// A coarse category for analytics: `network`, `server`, `client` (4xx) or
/// `unknown`. Never includes the message, which may carry user input.
String errorKind(Object? error) {
  if (error is ApiException) {
    if (error.isNetworkFailure) return 'network';
    if (error.isServerError) return 'server';
    return 'client';
  }
  if (error is AppwriteException) {
    if (_isAppwriteTransport(error)) return 'network';
    if ((error.code ?? 0) >= 500) return 'server';
    return 'client';
  }
  return 'unknown';
}

/// A short technical detail to show alongside the friendly message, so a user
/// reporting a problem can say something more useful than "it didn't work".
/// Returns null when there is nothing worth showing.
String? detailForError(Object? error) {
  if (error is ApiException) {
    if (error.isNetworkFailure) {
      return _transportDetail(error.message);
    }
    return 'HTTP ${error.statusCode}';
  }
  if (error is AppwriteException) {
    if (_isAppwriteTransport(error)) {
      return _transportDetail(error.message ?? '');
    }
    final type = error.type;
    return type == null || type.isEmpty
        ? 'Appwrite ${error.code}'
        : 'Appwrite ${error.code} $type';
  }
  return null;
}

/// Reduces a transport error to its first, most telling line. The raw text
/// carries the request URL and the OS errno as well, which wraps to several
/// lines on a phone and buries the part worth quoting.
String? _transportDetail(String raw) {
  var detail = raw.replaceFirst('Network error: ', '').trim();
  detail = detail.replaceFirst('ClientException with ', '');
  for (final marker in [', uri=', ' (OS Error']) {
    final at = detail.indexOf(marker);
    if (at > 0) detail = detail.substring(0, at);
  }
  detail = detail.trim();
  if (detail.isEmpty) return null;
  return detail.length > 100 ? '${detail.substring(0, 99)}…' : detail;
}
