import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:push/push.dart';

import '../config/app_config.dart';
import 'appwrite_push_channel.dart';
import 'push_registrar.dart';
import 'push_topic.dart';
import 'topic_subscriptions.dart';

/// Top-level background-message handler. The OS displays notification-type
/// messages automatically; taps are delivered to [Push.addOnNotificationTap].
@pragma('vm:entry-point')
Future<void> onBackgroundPushMessage(RemoteMessage message) async {
  // No work needed in the background isolate.
}

/// Device push, on the transport Appwrite recommends for each platform:
///
///  * **Android: Appwrite Push** ([AppwritePushChannel]), Appwrite's own
///    provider over its MQTT broker. No Firebase.
///  * **iOS: APNs** through the `push` plugin, with the APNs token registered
///    against the APNs provider. Appwrite Push on Flutter iOS only reaches a
///    running app, so APNs stays for delivery while it is suspended.
///
/// All plugin access is guarded so the app runs normally on platforms where
/// push is unavailable (desktop) or unconfigured.
class PushNotificationService {
  PushNotificationService(
    this._registrar,
    this._topics, {
    AppwritePushChannel? appwritePush,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _appwrite = appwritePush,
       _local = localNotifications ?? FlutterLocalNotificationsPlugin();

  final PushRegistrar _registrar;
  final TopicSubscriptions _topics;

  /// Set on Android only; null means the APNs path.
  final AppwritePushChannel? _appwrite;
  final FlutterLocalNotificationsPlugin _local;

  bool _available = false;
  bool _initialized = false;
  bool _signedIn = false;
  bool _registering = false;
  void Function(String postId)? _onOpenThread;
  final List<VoidCallback> _unsubscribes = [];

  /// True once the push plugin set up successfully on this platform.
  bool get isAvailable => _available;

  /// Wires notification channels and message listeners. [onOpenThread] is
  /// called with a post id when the user taps a notification.
  Future<void> initialize({
    required void Function(String postId) onOpenThread,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _onOpenThread = onOpenThread;

    final appwrite = _appwrite;
    if (appwrite != null) {
      try {
        await appwrite.start(onOpenThread: onOpenThread);
        _available = true;
      } catch (error) {
        debugPrint('Appwrite Push unavailable: $error');
        return;
      }
      if (_signedIn) {
        await requestPermission();
        await appwrite.onSignedIn();
      }
      return;
    }

    try {
      await _setUpLocalNotifications();

      _unsubscribes.add(Push.instance.addOnMessage(_showForeground));
      _unsubscribes.add(
        Push.instance.addOnBackgroundMessage(onBackgroundPushMessage),
      );
      _unsubscribes.add(Push.instance.addOnNotificationTap(_handleTapData));
      _unsubscribes.add(
        Push.instance.addOnNewToken((token) {
          if (_signedIn) _registrar.register(token, providerId: _providerId());
        }),
      );

      // App launched from terminated state by tapping a notification.
      final launchData =
          await Push.instance.notificationTapWhichLaunchedAppFromTerminated;
      if (launchData != null) _handleTapData(launchData);

      _available = true;
    } catch (error) {
      debugPrint('Push unavailable on this platform: $error');
      return;
    }

    // Handles the case where the user was already signed in before init.
    await _registerIfPossible();
  }

  /// Requests OS notification permission via permission_handler. Returns true
  /// if granted (or provisionally granted on iOS).
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted || status.isProvisional || status.isLimited;
    } catch (_) {
      return false;
    }
  }

  /// Called when the user signs in. Registers the device token if push is
  /// available now, otherwise defers until [initialize] completes.
  Future<void> onSignedIn() async {
    _signedIn = true;
    final appwrite = _appwrite;
    if (appwrite != null) {
      if (!_available) return; // initialize() picks it up.
      await requestPermission();
      await appwrite.onSignedIn();
      return;
    }
    await _registerIfPossible();
  }

  /// Called on sign-out: removes the Appwrite push target.
  Future<void> onSignedOut() async {
    _signedIn = false;
    _registering = false;
    final appwrite = _appwrite;
    if (appwrite != null) {
      await appwrite.onSignedOut();
      return;
    }
    await _registrar.unregister();
  }

  /// Turns a notification topic on or off: the Messaging subscriber for this
  /// device's target, and on Android the live Appwrite Push subscription.
  Future<void> setTopicEnabled(PushTopic topic, bool enabled) async {
    await _topics.setEnabled(topic, enabled);
    await _appwrite?.applyTopic(topic, enabled);
  }

  /// Registers the current device token against the matching Appwrite provider.
  /// Idempotent and safe to call from both [onSignedIn] and [initialize].
  Future<void> _registerIfPossible() async {
    if (!_available || !_signedIn || _registering) return;
    _registering = true;

    await requestPermission();
    try {
      final token = await Push.instance.token;
      // On iOS the APNS token may not be ready yet; addOnNewToken will register
      // it once available.
      if (token != null) {
        final targetId = await _registrar.register(
          token,
          providerId: _providerId(),
        );
        if (targetId != null) await _topics.syncOnRegister(targetId);
      }
    } catch (error) {
      debugPrint('Could not register push token: $error');
    }
  }

  /// The `push` plugin path is iOS-only, so its tokens are APNs tokens.
  String _providerId() => AppConfig.apnsProviderId;

  Future<void> _setUpLocalNotifications() async {
    const androidChannel = AndroidNotificationChannel(
      AppConfig.androidNotificationChannelId,
      AppConfig.androidNotificationChannelName,
      importance: Importance.high,
    );

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _openFromPayload(payload);
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  void _showForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConfig.androidNotificationChannelId,
          AppConfig.androidNotificationChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(_stringKeyed(message.data)),
    );
  }

  void _handleTapData(Map<String?, Object?> data) {
    final postId = data['postId'];
    if (postId is String && postId.isNotEmpty) {
      _onOpenThread?.call(postId);
    }
  }

  void _openFromPayload(String payload) {
    try {
      final data = jsonDecode(payload);
      final postId = data is Map ? data['postId'] : null;
      if (postId is String && postId.isNotEmpty) {
        _onOpenThread?.call(postId);
      }
    } catch (_) {
      // Malformed payload — ignore.
    }
  }

  Map<String, Object?> _stringKeyed(Map<String?, Object?>? data) {
    if (data == null) return const {};
    return {
      for (final entry in data.entries)
        if (entry.key != null) entry.key!: entry.value,
    };
  }

  void dispose() {
    _appwrite?.dispose();
    for (final unsubscribe in _unsubscribes) {
      unsubscribe();
    }
    _unsubscribes.clear();
  }
}
