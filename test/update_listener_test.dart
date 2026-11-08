import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:refetch/core/update/app_update_service.dart';
import 'package:refetch/core/update/update_listener.dart';

AppUpdateInfo _info({
  UpdateAvailability availability = UpdateAvailability.updateAvailable,
  InstallStatus status = InstallStatus.unknown,
  bool flexibleAllowed = true,
}) => AppUpdateInfo(
  updateAvailability: availability,
  immediateUpdateAllowed: true,
  immediateAllowedPreconditions: null,
  flexibleUpdateAllowed: flexibleAllowed,
  flexibleAllowedPreconditions: null,
  availableVersionCode: 7,
  installStatus: status,
  packageName: 'io.appwrite.refetch',
  clientVersionStalenessDays: 0,
  updatePriority: 0,
);

class _FakeService implements AppUpdateService {
  _FakeService(this.info, {this.result});

  AppUpdateInfo? info;
  final Future<AppUpdateResult?>? result;
  int starts = 0;
  int completes = 0;

  @override
  bool? get debugIsAndroid => true;

  @override
  Future<AppUpdateInfo?> checkForUpdate() async => info;

  @override
  Future<AppUpdateResult?> startFlexibleUpdate() {
    starts++;
    return result ?? Future.value(AppUpdateResult.success);
  }

  @override
  Future<void> completeFlexibleUpdate() async => completes++;
}

Future<void> _pump(
  WidgetTester tester,
  _FakeService service, {
  Duration timeout = const Duration(minutes: 5),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appUpdateServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        scaffoldMessengerKey: rootMessengerKey,
        builder: (context, child) =>
            UpdateListener(flexibleTimeout: timeout, child: child!),
        home: const Scaffold(body: Text('feed')),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('accepted update offers Restart, which installs it', (
    tester,
  ) async {
    final service = _FakeService(_info());
    await _pump(tester, service);

    expect(service.starts, 1);
    expect(find.text(UpdateListener.readyMessage), findsOneWidget);
    await tester.pump(const Duration(seconds: 1)); // snackbar slides in
    await tester.tap(find.text(UpdateListener.restartLabel));
    expect(service.completes, 1);
  });

  testWidgets('declined update shows nothing', (tester) async {
    final service = _FakeService(
      _info(),
      result: Future.value(AppUpdateResult.userDeniedUpdate),
    );
    await _pump(tester, service);

    expect(service.starts, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('no update: no prompt, no snackbar', (tester) async {
    final service = _FakeService(
      _info(availability: UpdateAvailability.updateNotAvailable),
    );
    await _pump(tester, service);

    expect(service.starts, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('flexible not allowed: does not start', (tester) async {
    final service = _FakeService(_info(flexibleAllowed: false));
    await _pump(tester, service);

    expect(service.starts, 0);
  });

  testWidgets('already downloaded offers Restart without re-downloading', (
    tester,
  ) async {
    final service = _FakeService(_info(status: InstallStatus.downloaded));
    await _pump(tester, service);

    expect(service.starts, 0);
    expect(find.text(UpdateListener.readyMessage), findsOneWidget);
  });

  testWidgets('dead in-progress update points at the Store', (tester) async {
    final service = _FakeService(
      _info(
        availability: UpdateAvailability.developerTriggeredUpdateInProgress,
        status: InstallStatus.pending,
      ),
    );
    await _pump(tester, service);

    expect(service.starts, 0);
    expect(find.text(UpdateListener.stuckMessage), findsOneWidget);
    expect(find.text(UpdateListener.openStoreLabel), findsOneWidget);
  });

  testWidgets('a download that never finishes times out to stuck', (
    tester,
  ) async {
    final service = _FakeService(
      _info(),
      result: Completer<AppUpdateResult?>().future,
    );
    await _pump(tester, service, timeout: const Duration(seconds: 1));
    expect(find.byType(SnackBar), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text(UpdateListener.stuckMessage), findsOneWidget);
  });

  testWidgets('download finishing in the background shows on resume', (
    tester,
  ) async {
    final service = _FakeService(
      _info(availability: UpdateAvailability.updateNotAvailable),
    );
    await _pump(tester, service);
    expect(find.byType(SnackBar), findsNothing);

    service.info = _info(status: InstallStatus.downloaded);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.text(UpdateListener.readyMessage), findsOneWidget);
  });
}
