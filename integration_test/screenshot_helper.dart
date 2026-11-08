import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Captures store-listing screenshots from an integration test.
///
/// The paired driver in `test_driver/integration_test.dart` decides where the
/// files land (`build/screenshots/`); this class owns naming, ordering, and the
/// Android surface conversion that `takeScreenshot` requires.
///
/// ## Fail loudly
///
/// The failure this exists to prevent is a run that reports success while
/// capturing nothing, which is what happens when navigation steps are wrapped
/// in try/catch and every one of them quietly misses. Do not swallow errors in
/// navigation steps, and always finish with [assertCaptured].
class ScreenshotHelper {
  ScreenshotHelper(this._binding);

  final IntegrationTestWidgetsFlutterBinding _binding;
  final List<String> _captured = <String>[];
  bool _surfaceConverted = false;

  /// Names captured so far, in order.
  List<String> get captured => List.unmodifiable(_captured);

  /// On Android `takeScreenshot` only works once the Flutter surface has been
  /// converted to an image, and converting twice throws. Call this before the
  /// first [take]; calling it again is a no-op.
  Future<void> prepare(WidgetTester tester) async {
    if (_surfaceConverted) return;
    await _binding.convertFlutterSurfaceToImage();
    await tester.pump(const Duration(milliseconds: 100));
    _surfaceConverted = true;
  }

  /// Capture a screenshot named `NN_[name]`, zero-padded so the files sort in
  /// capture order, which is also the order the store shows them in.
  Future<void> take(WidgetTester tester, String name) async {
    if (!_surfaceConverted) {
      fail(
        'ScreenshotHelper.prepare() must be called before take("$name"). '
        'Without it takeScreenshot returns an empty image on Android.',
      );
    }
    // Let images (favicons) and animations land before the shot.
    await settle(tester, const Duration(seconds: 2));
    final index = (_captured.length + 1).toString().padLeft(2, '0');
    final screenshotName = '${index}_$name';
    await _binding.takeScreenshot(screenshotName);
    _captured.add(screenshotName);
  }

  /// Fail unless at least [minimum] screenshots were captured.
  void assertCaptured({int minimum = 1}) {
    expect(
      _captured.length,
      greaterThanOrEqualTo(minimum),
      reason:
          'Captured ${_captured.length} screenshots, expected at least '
          '$minimum. Check the navigation steps actually reached each screen.',
    );
  }
}

/// Pump frames for [duration] without waiting for everything to settle:
/// progress indicators and network images never "settle".
Future<void> settle(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pump until [finder] matches, or fail after [timeout]. The app loads live
/// data from Appwrite, so screens appear when the network answers.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out after ${timeout.inSeconds}s waiting for $finder');
}
