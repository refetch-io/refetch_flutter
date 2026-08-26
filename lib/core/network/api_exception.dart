/// Error thrown by [ApiClient] for non-2xx responses or transport failures.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  /// HTTP status code, or 0 for transport-level failures.
  final int statusCode;

  /// Human-readable message extracted from the response body when possible.
  final String message;

  /// Whether this represents an authentication failure the UI should react to.
  bool get isUnauthorized => statusCode == 401;

  /// The request never reached the server — DNS, TLS, timeout, airplane mode.
  /// [message] carries the underlying transport error, which is useful in a
  /// bug report but not something to show a user verbatim.
  bool get isNetworkFailure => statusCode == 0;

  /// The server was reached but failed to answer, so retrying may work.
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
