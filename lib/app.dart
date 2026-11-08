import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/analytics/analytics_providers.dart';
import 'core/push/push_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/update/update_listener.dart';
import 'features/auth/presentation/auth_controller.dart';

/// Root widget: wires the router and themes into [MaterialApp.router], starts
/// analytics, and drives push-notification setup off authentication state.
class RefetchApp extends ConsumerStatefulWidget {
  const RefetchApp({super.key});

  @override
  ConsumerState<RefetchApp> createState() => _RefetchAppState();
}

class _RefetchAppState extends ConsumerState<RefetchApp> {
  @override
  void initState() {
    super.initState();
    // Analytics: start the lifecycle events, then apply the saved choice
    // (nothing is sent until it has been read).
    ref.read(analyticsProvider).start();
    ref.read(analyticsConsentProvider);
    // Initialize push handling after first frame so the router exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(routerProvider);
      ref
          .read(pushNotificationServiceProvider)
          .initialize(onOpenThread: (postId) => router.push('/thread/$postId'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Register/unregister the device push target as auth state changes.
    ref.listen(authControllerProvider, (previous, next) {
      final wasSignedIn = previous?.value != null;
      final isSignedIn = next.value != null;
      final service = ref.read(pushNotificationServiceProvider);
      if (isSignedIn && !wasSignedIn) {
        // Registers the device token and subscribes to enabled topics.
        service.onSignedIn();
      } else if (!isSignedIn && wasSignedIn) {
        service.onSignedOut();
      }
    });

    return MaterialApp.router(
      title: 'Refetch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      scaffoldMessengerKey: rootMessengerKey,
      // Play flexible in-app update; a no-op off Android and in debug builds.
      builder: (context, child) => UpdateListener(child: child!),
    );
  }
}
