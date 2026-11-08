import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import 'app_update_service.dart';

/// Root messenger, so the update snackbars can show from above the router.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Drives Play's *flexible* update flow and reports it through a snackbar.
///
/// Ported from beej's `in_app_update` brick (lohanidamodar/beej).
///
/// Flexible rather than immediate: an immediate update blocks behind a
/// full-screen Play dialog until it finishes, which is a poor trade for a user
/// who opened the app to read the feed.
///
/// The flow has more states than it first appears, and each one here was a bug
/// somewhere before it was a branch:
///
///  * **Downloaded in a previous session.** The user accepted, the app was
///    killed, Play finished in the background. Offering a fresh download would
///    re-download an update already on disk — offer *Restart* instead.
///  * **`developerTriggeredUpdateInProgress`.** Play refuses to re-show the
///    consent sheet once a developer-triggered update is in progress. Resume
///    only if the download is genuinely alive; awaiting a dead one hangs
///    forever, so a dead session gets a recovery notice pointing at the Store.
///  * **A download that never finishes.** Bounded by [flexibleTimeout] so the
///    await resolves to "stuck" rather than never resolving.
///  * **Completion arriving on resume.** Play often reports `downloaded` only
///    after the next resume, so the check runs again then — guarded by
///    `_noticeShown` so the two paths cannot stack duplicate snackbars.
class UpdateListener extends ConsumerStatefulWidget {
  const UpdateListener({
    required this.child,
    this.flexibleTimeout = const Duration(minutes: 5),
    super.key,
  });

  final Widget child;

  /// Play finishes in seconds on a working network. Five minutes means the
  /// download is effectively dead — the service was killed, or the network
  /// went away mid-transfer.
  @visibleForTesting
  final Duration flexibleTimeout;

  static const readyMessage = 'Update downloaded';
  static const restartLabel = 'Restart';
  static const stuckMessage = 'An update is waiting to finish';
  static const openStoreLabel = 'Open Play Store';

  @override
  ConsumerState<UpdateListener> createState() => _UpdateListenerState();
}

class _UpdateListenerState extends ConsumerState<UpdateListener> {
  AppLifecycleListener? _lifecycle;

  /// Latches once any update snackbar has shown this session.
  bool _noticeShown = false;

  @override
  void initState() {
    super.initState();
    // After the first frame: the messenger has to exist before we can use it.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_checkOnStart()),
    );
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  void _onResume() {
    if (!_noticeShown) unawaited(_pollForDownloaded());
  }

  Future<void> _checkOnStart() async {
    final service = ref.read(appUpdateServiceProvider);
    final info = await service.checkForUpdate();
    if (info == null || !mounted) return;

    if (info.installStatus == InstallStatus.downloaded) {
      _showInstallReady(service);
      return;
    }

    if (info.updateAvailability ==
        UpdateAvailability.developerTriggeredUpdateInProgress) {
      if (info.installStatus == InstallStatus.downloading) {
        _handleResult(service, await _awaitFlexible(service));
      } else {
        _showStuck();
      }
      return;
    }

    if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
    if (!info.flexibleUpdateAllowed) return;
    _handleResult(service, await _awaitFlexible(service));
  }

  Future<void> _pollForDownloaded() async {
    final service = ref.read(appUpdateServiceProvider);
    final info = await service.checkForUpdate();
    if (info == null || info.installStatus != InstallStatus.downloaded) return;
    _showInstallReady(service);
  }

  Future<AppUpdateResult?> _awaitFlexible(AppUpdateService service) async {
    try {
      return await service.startFlexibleUpdate().timeout(
        widget.flexibleTimeout,
      );
    } on TimeoutException {
      return null;
    }
  }

  void _handleResult(AppUpdateService service, AppUpdateResult? result) {
    if (result == AppUpdateResult.success) {
      _showInstallReady(service);
      return;
    }
    // The user declining is a complete, correct outcome — say nothing.
    if (result == AppUpdateResult.userDeniedUpdate) return;
    _showStuck();
  }

  void _showInstallReady(AppUpdateService service) {
    final messenger = rootMessengerKey.currentState;
    if (_noticeShown || messenger == null || !mounted) return;
    _noticeShown = true;
    messenger.showSnackBar(
      SnackBar(
        content: const Text(UpdateListener.readyMessage),
        // Persistent: the install is worth surfacing until acted on, and the
        // close icon lets the user dismiss it.
        duration: const Duration(days: 1),
        showCloseIcon: true,
        action: SnackBarAction(
          label: UpdateListener.restartLabel,
          onPressed: () => unawaited(service.completeFlexibleUpdate()),
        ),
      ),
    );
  }

  void _showStuck() {
    final messenger = rootMessengerKey.currentState;
    if (_noticeShown || messenger == null || !mounted) return;
    _noticeShown = true;
    messenger.showSnackBar(
      SnackBar(
        content: const Text(UpdateListener.stuckMessage),
        duration: const Duration(days: 1),
        showCloseIcon: true,
        action: SnackBarAction(
          label: UpdateListener.openStoreLabel,
          onPressed: () => unawaited(_openStoreListing()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Opens the Play listing in the Play app, falling back to the web page when
/// Play is not installed.
Future<void> _openStoreListing() async {
  final id = AppConfig.androidApplicationId;
  try {
    if (await launchUrl(
      Uri.parse('market://details?id=$id'),
      mode: LaunchMode.externalApplication,
    )) {
      return;
    }
  } catch (_) {
    // Play is not installed; the web listing below still works.
  }
  try {
    await launchUrl(
      Uri.parse('https://play.google.com/store/apps/details?id=$id'),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    // Nothing else to try; the snackbar stays dismissible.
  }
}
