import 'package:appwrite/appwrite.dart';

import 'api_exception.dart';

/// Extracts a human-readable message from any error raised by the app's two
/// backends:
///  * [ApiException] — from the refetch.io REST client.
///  * [AppwriteException] — from the Appwrite SDK (auth, push targets).
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
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) return message;
  }
  return fallback;
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
    final code = error.code;
    return code == null ? null : 'Appwrite $code';
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
