import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../settings/presentation/notification_settings.dart';
import '../../settings/presentation/privacy_settings.dart';

/// Account screen: shows the signed-in user and a sign-out action, or a
/// sign-in prompt when signed out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Center(
        child: user == null
            ? ListView(
                shrinkWrap: true,
                children: [
                  EmptyState(
                    icon: LucideIcons.userRound,
                    title: 'You are not signed in',
                    message: 'Sign in to vote, comment and get replies.',
                    action: FilledButton(
                      onPressed: () => context.push('/signin'),
                      child: const Text('Sign in'),
                    ),
                  ),
                  const PrivacySettings(),
                ],
              )
            : ListView(
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: CircleAvatar(
                      radius: 36,
                      child: Text(
                        user.displayName.characters.first.toUpperCase(),
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      user.displayName,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      user.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const NotificationSettings(),
                  const Divider(height: 1),
                  const PrivacySettings(),
                  const Divider(height: 1),
                  const SizedBox(height: 24),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(authControllerProvider.notifier).signOut(),
                      icon: const Icon(LucideIcons.logOut, size: 18),
                      label: const Text('Sign out'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
