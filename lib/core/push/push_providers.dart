import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../appwrite/appwrite_providers.dart';
import 'appwrite_push_channel.dart';
import 'push_notification_service.dart';
import 'push_registrar.dart';
import 'push_target_store.dart';
import 'push_topic.dart';
import 'topic_subscriptions.dart';

final pushTargetStoreProvider = Provider<PushTargetStore>((ref) {
  return PrefsPushTargetStore();
});

final pushRegistrarProvider = Provider<PushRegistrar>((ref) {
  return PushRegistrar(
    ref.watch(accountProvider),
    ref.watch(pushTargetStoreProvider),
  );
});

final messagingProvider = Provider<Messaging>((ref) {
  return Messaging(ref.watch(appwriteClientProvider));
});

final pushPreferencesProvider = Provider<PushPreferences>((ref) {
  return PushPreferences();
});

final topicSubscriptionsProvider = Provider<TopicSubscriptions>((ref) {
  return TopicSubscriptions(
    ref.watch(messagingProvider),
    ref.watch(pushTargetStoreProvider),
    ref.watch(pushPreferencesProvider),
  );
});

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final registrar = ref.watch(pushRegistrarProvider);
  final topics = ref.watch(topicSubscriptionsProvider);
  final client = ref.watch(appwriteClientProvider);
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final service = PushNotificationService(
    registrar,
    topics,
    // Android: Appwrite Push. iOS: APNs through the `push` plugin.
    appwritePush: isAndroid
        ? AppwritePushChannel(
            registrar,
            topics,
            push: () => SdkLivePush(client),
          )
        : null,
  );
  ref.onDispose(service.dispose);
  return service;
});
