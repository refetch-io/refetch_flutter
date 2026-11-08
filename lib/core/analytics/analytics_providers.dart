import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../appwrite/appwrite_providers.dart';
import '../config/app_config.dart';
import 'analytics_service.dart';
import 'appwrite_analytics.dart';

/// Remembers whether the user allows anonymous usage analytics. On by
/// default, matching refetch.io; switched off in Account.
class AnalyticsConsentStore {
  static const _key = 'analytics.enabled';

  Future<bool> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  Future<void> write(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final analyticsConsentStoreProvider = Provider<AnalyticsConsentStore>(
  (ref) => AnalyticsConsentStore(),
);

/// The analytics backend before consent is applied: Appwrite when a property
/// is configured, otherwise nothing. Override this to swap backends.
final analyticsBackendProvider = Provider<AnalyticsService>((ref) {
  if (AppConfig.analyticsPropertyId.isEmpty) return const NoopAnalytics();
  return AppwriteAnalyticsService.forClient(
    ref.watch(appwriteClientProvider),
    AppConfig.analyticsPropertyId,
  );
});

/// The service the app uses. Holds events until the saved choice is read
/// (see [AnalyticsConsentController]), so nothing leaves before we know.
final analyticsProvider = Provider<ConsentedAnalytics>((ref) {
  final analytics = ConsentedAnalytics(
    ref.watch(analyticsBackendProvider),
    enabled: null,
  );
  ref.onDispose(analytics.stop);
  return analytics;
});

/// The user's analytics choice, applied to [analyticsProvider].
class AnalyticsConsentController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final enabled = await ref.read(analyticsConsentStoreProvider).read();
    ref.read(analyticsProvider).enabled = enabled;
    return enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    final analytics = ref.read(analyticsProvider);
    // Record the change only while allowed: opting out sends nothing, opting
    // in is recorded once it is on.
    if (!enabled) analytics.enabled = false;
    await ref.read(analyticsConsentStoreProvider).write(enabled);
    analytics.enabled = enabled;
    if (enabled) {
      analytics.track(
        AnalyticsEvents.settingChanged,
        props: {'setting': 'analytics', 'value': true},
      );
    }
    state = AsyncData(enabled);
  }
}

final analyticsConsentProvider =
    AsyncNotifierProvider<AnalyticsConsentController, bool>(
      AnalyticsConsentController.new,
    );

/// Sends a screen view whenever a named route becomes the visible one.
/// go_router names each page after its route's `name` (or its path pattern),
/// so ids never reach analytics.
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver(this._analytics);

  final AnalyticsService _analytics;

  void _view(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (route is! PageRoute || name == null || name.isEmpty) return;
    _analytics.screenView(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _view(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _view(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _view(previousRoute);
}
