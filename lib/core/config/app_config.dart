/// Static configuration for the Refetch app.
///
/// The app talks to two backends:
///  * Appwrite (auth only) via the Dart SDK.
///  * The existing refetch.io REST API for reads and mutations.
class AppConfig {
  AppConfig._();

  /// Appwrite Cloud endpoint hosting the refetch project.
  static const String appwriteEndpoint = 'https://fra.cloud.appwrite.io/v1';

  /// Refetch Appwrite project id.
  static const String appwriteProjectId = '63ef1792594ff4f50de2';

  /// Base URL of the refetch.io Next.js API.
  static const String apiBaseUrl = 'https://refetch.io';

  /// Page size used for feed pagination.
  static const int feedPageSize = 25;

  /// Brand colour (refetch purple).
  static const int brandColor = 0xFF7C3AED;

  /// Appwrite Messaging topic ids the device subscribes its push target to
  /// (client-side, via `Messaging.createSubscriber`). Empty ids are skipped.
  static const String digestTopicId = 'weekly-digest';
  static const String repliesTopicId = 'replies';

  /// Appwrite Messaging provider ids. Android registers its FCM token against
  /// the FCM provider; iOS registers its APNS token against the APNS provider —
  /// each provider delivers directly to its platform (no FCM→APNS relay). If
  /// either is left empty, Appwrite falls back to picking a provider by the
  /// target's platform, which fails silently when none is configured.
  static const String fcmProviderId = '6a1bb5a3001dc2d85de3';
  static const String apnsProviderId = '6a8a7cc54e645db3829c';

  /// Android notification channel used for foreground display.
  static const String androidNotificationChannelId = 'refetch_default';
  static const String androidNotificationChannelName = 'Refetch';
}
