import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/analytics/analytics_providers.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/network/error_message.dart';
import '../../../core/push/push_providers.dart';
import '../../../core/push/push_topic.dart';

/// Notification controls in the account page: the OS permission state plus a
/// per-topic enable/disable switch. Each switch subscribes/unsubscribes the
/// device's push target to the Appwrite Messaging topic (client-side).
class NotificationSettings extends ConsumerStatefulWidget {
  const NotificationSettings({super.key});

  @override
  ConsumerState<NotificationSettings> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState extends ConsumerState<NotificationSettings> {
  final Map<PushTopic, bool> _enabled = {};
  bool _loading = true;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = ref.read(pushPreferencesProvider);
    final status = await Permission.notification.status;
    for (final topic in PushTopic.configured) {
      _enabled[topic] = await prefs.isEnabled(topic);
    }
    if (mounted) {
      setState(() {
        _permissionGranted = status.isGranted;
        _loading = false;
      });
    }
  }

  Future<void> _grantPermission() async {
    final granted = await ref
        .read(pushNotificationServiceProvider)
        .requestPermission();
    if (!mounted) return;
    if (!granted) {
      // Likely permanently denied — send the user to system settings.
      final status = await Permission.notification.status;
      if (status.isPermanentlyDenied) await openAppSettings();
    }
    final refreshed = await Permission.notification.status;
    if (mounted) setState(() => _permissionGranted = refreshed.isGranted);
  }

  Future<void> _toggle(PushTopic topic, bool value) async {
    setState(() => _enabled[topic] = value);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (value && !_permissionGranted) await _grantPermission();
      await ref.read(topicSubscriptionsProvider).setEnabled(topic, value);
      ref
          .read(analyticsProvider)
          .track(
            AnalyticsEvents.settingChanged,
            props: {'setting': 'push_${topic.topicId}', 'value': value},
          );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Subscribed to ${topic.label}'
                  : 'Unsubscribed from ${topic.label}',
            ),
          ),
        );
    } catch (error) {
      if (mounted) setState(() => _enabled[topic] = !value);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              messageForError(
                error,
                fallback: 'Could not update subscription.',
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final topics = PushTopic.configured;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Notifications',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (!_permissionGranted)
          ListTile(
            leading: const Icon(LucideIcons.bellOff),
            title: const Text('Allow notifications'),
            subtitle: const Text('Required to receive push notifications'),
            trailing: FilledButton(
              onPressed: _grantPermission,
              child: const Text('Allow'),
            ),
          ),
        if (topics.isEmpty)
          const ListTile(
            dense: true,
            title: Text('No notification topics are configured yet.'),
          )
        else
          for (final topic in topics)
            SwitchListTile(
              title: Text(topic.label),
              subtitle: Text(topic.description),
              value: _enabled[topic] ?? true,
              onChanged: (value) => _toggle(topic, value),
            ),
      ],
    );
  }
}
