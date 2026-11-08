import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';

import 'analytics_service.dart';

/// [AnalyticsService] on Appwrite Analytics, through the SDK's [Tracking]
/// helper: it sends `createEvent` calls, flattens props, reports the viewport
/// width, adds `app_backgrounded`/`app_foregrounded` with engagement time, and
/// swallows network errors so analytics never breaks the app.
///
/// Events are anonymous: no `userId` is ever passed (the endpoint only takes
/// one from an API key), and the session cookie the client carries is not used
/// to attribute events.
class AppwriteAnalyticsService implements AnalyticsService {
  AppwriteAnalyticsService(this._tracking);

  /// Builds the tracker for [propertyId] on [client].
  factory AppwriteAnalyticsService.forClient(
    Client client,
    String propertyId,
  ) => AppwriteAnalyticsService(
    Tracking(
      kDebugMode ? DebugLoggingAnalytics(client) : Analytics(client),
      propertyId,
    ),
  );

  final Tracking _tracking;

  @override
  void start() => _tracking.enableAutoLifecycleEvents();

  @override
  void stop() => _tracking.disableAutoLifecycleEvents();

  @override
  void screenView(String screen, {Map<String, Object?>? props}) {
    // The screen name doubles as the event URL path (`app://android/thread`).
    _tracking.screenView(screen, props: cleanProps(props));
  }

  @override
  void track(String name, {Map<String, Object?>? props}) {
    _tracking.event(name, props: cleanProps(props, maxPairs: 16));
  }
}

/// Debug builds only: logs each event and what the server answered, since
/// [Tracking] deliberately swallows failures. `flutter logs` then shows
/// `[analytics] screen_view -> sent` or the error (e.g. a 404 for a wrong
/// property id, a 403 for an origin allowlist).
class DebugLoggingAnalytics extends Analytics {
  DebugLoggingAnalytics(super.client);

  @override
  Future createEvent({
    required String propertyId,
    required String name,
    required String url,
    String? domain,
    String? referrer,
    int? screenWidth,
    String? sessionHash,
    int? scrollDepth,
    int? engagementTime,
    List<String>? props,
    String? userId,
    String? ip,
    String? userAgent,
    bool? interactive,
  }) async {
    try {
      final result = await super.createEvent(
        propertyId: propertyId,
        name: name,
        url: url,
        domain: domain,
        referrer: referrer,
        screenWidth: screenWidth,
        sessionHash: sessionHash,
        scrollDepth: scrollDepth,
        engagementTime: engagementTime,
        props: props,
        userId: userId,
        ip: ip,
        userAgent: userAgent,
        interactive: interactive,
      );
      debugPrint('[analytics] $name $url ${props ?? const []} -> sent');
      return result;
    } catch (error) {
      debugPrint('[analytics] $name $url -> FAILED: $error');
      rethrow;
    }
  }
}
