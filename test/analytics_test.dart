import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refetch/core/analytics/analytics_providers.dart';
import 'package:refetch/core/analytics/analytics_service.dart';
import 'package:refetch/core/analytics/appwrite_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeClient extends Fake implements Client {}

/// The SDK's Analytics service with the network call replaced by a recorder,
/// so these tests run the real `Tracking` helper end to end.
class _RecordingAnalytics extends Analytics {
  _RecordingAnalytics() : super(_FakeClient());

  final List<Map<String, Object?>> events = [];

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
    events.add({
      'propertyId': propertyId,
      'name': name,
      'url': url,
      'props': props,
      'userId': userId,
      'interactive': interactive,
    });
  }
}

/// Records calls made through the [AnalyticsService] interface.
class _SpyService implements AnalyticsService {
  final List<String> calls = [];

  @override
  void start() => calls.add('start');

  @override
  void stop() => calls.add('stop');

  @override
  void screenView(String screen, {Map<String, Object?>? props}) =>
      calls.add('screen:$screen');

  @override
  void track(String name, {Map<String, Object?>? props}) =>
      calls.add('track:$name${props == null ? '' : ' $props'}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppwriteAnalyticsService (via the SDK Tracking helper)', () {
    late _RecordingAnalytics analytics;
    late AppwriteAnalyticsService service;

    setUp(() {
      analytics = _RecordingAnalytics();
      service = AppwriteAnalyticsService(Tracking(analytics, 'prop-123'));
    });

    tearDown(() => service.stop());

    test('track sends the name, flattened props and no user id', () async {
      service.track(
        'story_shared',
        props: {'post_id': 'p1', 'source': 'feed', 'skip': null},
      );
      await Future<void>.delayed(Duration.zero);

      final event = analytics.events.single;
      expect(event['propertyId'], 'prop-123');
      expect(event['name'], 'story_shared');
      expect(event['props'], ['post_id', 'p1', 'source', 'feed']);
      expect(event['userId'], isNull);
      expect(event['url'], startsWith('app://'));
    });

    test(
      'screenView becomes screen_view with the screen as the URL path',
      () async {
        service.screenView('thread');
        await Future<void>.delayed(Duration.zero);

        final event = analytics.events.single;
        expect(event['name'], 'screen_view');
        expect(event['url'], endsWith('/thread'));
        expect(event['props'], containsAllInOrder(['screen', 'thread']));
      },
    );

    test(
      'start reports backgrounding as non-interactive; stop ends it',
      () async {
        final binding = TestWidgetsFlutterBinding.instance;
        service.start();
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await Future<void>.delayed(Duration.zero);
        expect(analytics.events.map((e) => e['name']), ['app_backgrounded']);
        expect(analytics.events.single['interactive'], isFalse);

        service.stop();
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        expect(analytics.events, hasLength(1), reason: 'nothing after stop');
      },
    );
  });

  group('ConsentedAnalytics', () {
    test('forwards only while enabled', () {
      final spy = _SpyService();
      final analytics = ConsentedAnalytics(spy, enabled: false);

      analytics.track('a');
      analytics.screenView('feed');
      expect(spy.calls, isEmpty);

      analytics.enabled = true;
      analytics.track('b');
      expect(spy.calls, ['track:b']);
    });

    test('holds events until consent is known, then sends them', () {
      final spy = _SpyService();
      final analytics = ConsentedAnalytics(spy, enabled: null)..start();
      analytics.screenView('feed');
      expect(spy.calls, isEmpty, reason: 'nothing leaves before we know');

      analytics.enabled = true;
      expect(spy.calls, ['start', 'screen:feed']);
    });

    test('held events are dropped when consent turns out to be off', () {
      final spy = _SpyService();
      final analytics = ConsentedAnalytics(spy, enabled: null)..start();
      analytics.screenView('feed');
      analytics.enabled = false;
      analytics.enabled = true;
      expect(spy.calls, ['start'], reason: 'the held view was dropped');
    });

    test('the hold is bounded', () {
      final spy = _SpyService();
      final analytics = ConsentedAnalytics(spy, enabled: null);
      for (var i = 0; i < 50; i++) {
        analytics.track('e$i');
      }
      analytics.enabled = true;
      expect(spy.calls, hasLength(ConsentedAnalytics.maxPending));
    });

    test('turning it off stops automatic events', () {
      final spy = _SpyService();
      final analytics = ConsentedAnalytics(spy)..start();
      analytics.enabled = false;
      expect(spy.calls, ['start', 'stop']);
    });
  });

  test('cleanProps drops nulls and caps the pair count', () {
    final many = {for (var i = 0; i < 40; i++) 'k$i': i};
    expect(cleanProps(many), hasLength(15));
    expect(cleanProps({'a': null, 'b': 1}), {'b': 1});
    expect(cleanProps(null), isEmpty);
  });

  group('AnalyticsRouteObserver', () {
    test('sends named page routes and ignores unnamed ones', () {
      final spy = _SpyService();
      final observer = AnalyticsRouteObserver(spy);
      final feed = MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'feed'),
        builder: (_) => const SizedBox(),
      );
      final thread = MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'thread'),
        builder: (_) => const SizedBox(),
      );
      final anonymous = MaterialPageRoute<void>(
        builder: (_) => const SizedBox(),
      );

      observer.didPush(feed, null);
      observer.didPush(thread, feed);
      observer.didPop(thread, feed);
      observer.didPush(anonymous, feed);

      expect(spy.calls, ['screen:feed', 'screen:thread', 'screen:feed']);
    });
  });

  group('analytics consent', () {
    ProviderContainer containerWith(_SpyService spy) {
      final container = ProviderContainer(
        overrides: [analyticsBackendProvider.overrideWithValue(spy)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('is on by default', () async {
      SharedPreferences.setMockInitialValues({});
      final spy = _SpyService();
      final container = containerWith(spy);

      expect(await container.read(analyticsConsentProvider.future), isTrue);
      container.read(analyticsProvider).track('x');
      expect(spy.calls, ['track:x']);
    });

    test('a saved opt-out is honoured before anything is sent', () async {
      SharedPreferences.setMockInitialValues({'analytics.enabled': false});
      final spy = _SpyService();
      final container = containerWith(spy);
      final analytics = container.read(analyticsProvider)..start();

      analytics.track('early');
      expect(await container.read(analyticsConsentProvider.future), isFalse);
      analytics.track('later');
      expect(spy.calls, isEmpty);
    });

    test('opting out persists, sends nothing; opting in is recorded', () async {
      SharedPreferences.setMockInitialValues({});
      final spy = _SpyService();
      final container = containerWith(spy);
      await container.read(analyticsConsentProvider.future);

      await container.read(analyticsConsentProvider.notifier).setEnabled(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('analytics.enabled'), isFalse);
      container.read(analyticsProvider).track('dropped');
      expect(spy.calls, isEmpty);

      await container.read(analyticsConsentProvider.notifier).setEnabled(true);
      expect(spy.calls.single, startsWith('track:setting_changed'));
      expect(prefs.getBool('analytics.enabled'), isTrue);
    });
  });
}
