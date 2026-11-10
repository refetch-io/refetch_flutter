/// Static configuration for the Refetch app.
///
/// The app talks to two backends:
///  * Appwrite via the Dart SDK: auth, push, analytics, and public reads
///    (posts, comments) straight from TablesDB.
///  * The refetch.io app API (`/api/app/*`, documented in the web repo's
///    `docs/APP_API.md`) for writes and the signed-in person's votes.
class AppConfig {
  AppConfig._();

  /// Appwrite Cloud endpoint hosting the refetch project.
  static const String appwriteEndpoint = 'https://fra.cloud.appwrite.io/v1';

  /// Refetch Appwrite project id.
  static const String appwriteProjectId = '63ef1792594ff4f50de2';

  /// Public site; the base URL of the app API and of shared thread links.
  static const String apiBaseUrl = 'https://refetch.io';

  /// Play package name (`applicationId` in android/app/build.gradle.kts), used
  /// by the in-app update's "Open Play Store" fallback.
  static const String androidApplicationId = 'io.appwrite.refetch';

  /// TablesDB ids, as in the web repo's `env.example`.
  static const String databaseId = '688f787e002c78bd299f';
  static const String postsTableId = '688f78a20022f61836ff';
  static const String commentsTableId = '68993e6c003af0fe657f';

  /// Appwrite Analytics property for the apps (separate from the website's).
  /// Override at build time with `--dart-define=ANALYTICS_PROPERTY_ID=...`;
  /// an empty value turns analytics off entirely.
  static const String analyticsPropertyId = String.fromEnvironment(
    'ANALYTICS_PROPERTY_ID',
    defaultValue: '6aeff5fb00101bdbf718',
  );

  /// Page size used for feed pagination.
  static const int feedPageSize = 25;

  /// Brand colour (refetch purple, `--brand` on refetch.io; see docs/BRANDING.md).
  static const int brandColor = 0xFF4E1CB3;

  /// Appwrite Messaging topic ids the device subscribes its push target to
  /// (client-side, via `Messaging.createSubscriber`). Empty ids are skipped.
  static const String digestTopicId = 'weekly-digest';
  static const String repliesTopicId = 'replies';

  /// Appwrite Messaging provider ids. Every target names its provider: without
  /// one, Appwrite assigns any enabled push provider, possibly the wrong one.
  ///
  /// iOS registers its APNs token against the APNs provider, as Appwrite
  /// recommends for Flutter on iOS (its own push only reaches a running app).
  static const String apnsProviderId = '6a8a7cc54e645db3829c';

  /// Appwrite Push, Appwrite's own provider (an MQTT broker the SDK connects
  /// to): Android delivery, with no Firebase. See docs/PUSH.md.
  static const String appwritePushProviderId = '6af28d0b00167c6b3005';

  /// Android notification channel used for foreground display.
  static const String androidNotificationChannelId = 'refetch_default';
  static const String androidNotificationChannelName = 'Refetch';
}
