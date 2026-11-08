import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_providers.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/error_message.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

/// Holds the current authentication state as an [AsyncValue<AppUser?>].
///
/// `data(null)` means signed out; `data(user)` means signed in; `loading`
/// covers the initial session check and in-flight sign in/up.
class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() {
    return ref.read(authRepositoryProvider).currentUser();
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signIn(email, password),
    );
    _afterAuth(AnalyticsEvents.signedIn);
  }

  Future<void> signUp(String name, String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signUp(name, email, password),
    );
    _afterAuth(AnalyticsEvents.signedUp);
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncValue.data(null);
    ref.read(analyticsProvider).track(AnalyticsEvents.signedOut);
  }

  void _afterAuth(String event) {
    final analytics = ref.read(analyticsProvider);
    if (state.hasError) {
      analytics.track(
        AnalyticsEvents.signInFailed,
        props: {
          'method': 'email',
          'flow': event,
          'reason': errorKind(state.error),
        },
      );
      return;
    }
    analytics.track(event, props: {'method': 'email'});
    // Create or rename the person's refetch.io profile, as the website does
    // on sign-in. Best effort: the app works without it.
    unawaited(
      ref
          .read(apiClientProvider)
          .post('/api/app/session')
          .then<void>((_) {})
          .catchError(
            (Object error) => debugPrint('Profile sync failed: $error'),
          ),
    );
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);

/// Convenience: the signed-in user, or `null` while loading / signed out.
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authControllerProvider).value;
});
