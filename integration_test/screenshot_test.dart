import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:refetch/app.dart';
import 'package:refetch/core/analytics/analytics_providers.dart';
import 'package:refetch/core/analytics/analytics_service.dart';
import 'package:refetch/features/feed/presentation/post_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screenshot_helper.dart';

/// Captures the store screenshots from the live feed.
///
/// ```sh
/// flutter drive \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/screenshot_test.dart \
///   -d <device>
/// ```
///
/// Files land in `build/screenshots/`; `tool/screenshot_job.dart` and moksha
/// turn them into store images (see screenshots/README.md). Scene names must
/// match the ids in `screenshots/headlines.json`.
///
/// Do not wrap steps in try/catch; see the note on [ScreenshotHelper].
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final screenshots = ScreenshotHelper(binding);

  testWidgets('store screenshots', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Screenshot runs must not show up in the app's analytics.
          analyticsBackendProvider.overrideWithValue(const NoopAnalytics()),
        ],
        child: const RefetchApp(),
      ),
    );

    // Top: the front page, ranked.
    await waitFor(tester, find.byType(PostCard));
    await screenshots.prepare(tester);
    await screenshots.take(tester, 'top');

    // A thread: the story, its AI summary and the discussion.
    await tester.tap(find.byType(PostCard).at(1));
    await waitFor(tester, find.text('Read article'));
    await screenshots.take(tester, 'thread');
    await tester.pageBack();
    await settle(tester, const Duration(seconds: 1));

    // New: the latest stories.
    await tester.tap(find.text('New'));
    await waitFor(tester, find.byType(PostCard));
    await screenshots.take(tester, 'new');

    // Account: the privacy switch, reachable without signing in.
    await tester.tap(find.byTooltip('Account'));
    await waitFor(tester, find.text('Share anonymous usage data'));
    await screenshots.take(tester, 'account');

    screenshots.assertCaptured(minimum: 4);
  });
}
