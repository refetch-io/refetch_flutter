import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_providers.dart';

/// The analytics switch in Account. Anonymous usage analytics are on by
/// default (as on refetch.io) and stop the moment this is turned off.
class PrivacySettings extends ConsumerWidget {
  const PrivacySettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(analyticsConsentProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Privacy', style: Theme.of(context).textTheme.titleSmall),
        ),
        SwitchListTile(
          title: const Text('Share anonymous usage data'),
          subtitle: const Text(
            'Which screens and features get used, so we know what to improve. '
            'Never your name, email or what you write.',
          ),
          value: consent.value ?? false,
          onChanged: consent.isLoading
              ? null
              : (value) => ref
                    .read(analyticsConsentProvider.notifier)
                    .setEnabled(value),
        ),
      ],
    );
  }
}
