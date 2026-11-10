import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'push_registrar.dart';
import 'push_topic.dart';
import 'topic_subscriptions.dart';

/// The parts of the SDK's [Push] that [AppwritePushChannel] uses, so the
/// channel's sign-in / topic / tap logic is testable without a broker.
abstract class LivePush {
  /// Subscribes with background delivery, which posts a notification per
  /// message. `null` [topics] means the signed-in user's own `users/<id>`
  /// topic. Resolves to a function that ends the subscription.
  Future<VoidCallback> subscribe(List<String>? topics);

  /// `data` of the notification whose tap launched the app, reported once.
  Future<Map<String, dynamic>?> initialTapData();

  /// Calls [onTap] with `data` for each later tap. Returns a stop function.
  VoidCallback onTap(void Function(Map<String, dynamic> data) onTap);

  /// Drops every subscription and stops background delivery (sign-out).
  void close();
}

/// [LivePush] over the SDK's [Push].
class SdkLivePush implements LivePush {
  SdkLivePush(Client client) : _push = Push(client);

  final Push _push;

  @override
  Future<VoidCallback> subscribe(List<String>? topics) async {
    final subscription = await _push.subscribe(
      topics,
      // The SDK posts the notification itself (notifyInForeground also while
      // the app is on screen, as FCM did), so the callback has nothing to do.
      (_) {},
      background: true,
      title: 'Refetch',
      notifyInForeground: true,
    );
    return subscription.unsubscribe;
  }

  @override
  Future<Map<String, dynamic>?> initialTapData() async =>
      (await _push.getInitialNotification())?.data;

  @override
  VoidCallback onTap(void Function(Map<String, dynamic> data) onTap) =>
      _push.onNotificationOpened((opened) => onTap(opened.data));

  @override
  void close() => _push.close();
}

/// Android push over Appwrite Push, Appwrite's own provider: the SDK keeps an
/// MQTT connection to Appwrite's broker and wakes the app on a schedule to
/// reconnect once it is closed. No Firebase, no device token.
///
/// On sign-in the device registers an Appwrite push target (needed for
/// topics), subscribes that target to the enabled Messaging topics, and opens
/// background subscriptions to the user's own topic plus those topics.
///
/// Per user, Appwrite then routes everything over Appwrite Push and sends that
/// user's APNs devices a generic "New message" wake-up instead of the full
/// notification. Accepted for users signed in on both platforms; see
/// docs/PUSH.md.
class AppwritePushChannel {
  AppwritePushChannel(
    this._registrar,
    this._topics, {
    required LivePush Function() push,
    Future<String> Function()? installId,
  }) : _pushFactory = push,
       _installId = installId ?? _prefsInstallId;

  final PushRegistrar _registrar;
  final TopicSubscriptions _topics;
  final LivePush Function() _pushFactory;
  final Future<String> Function() _installId;

  LivePush? _push;
  LivePush get _live => _push ??= _pushFactory();

  void Function(String postId)? _onOpenThread;
  VoidCallback? _stopTaps;
  bool _signedIn = false;

  /// Live subscriptions: `null` key is the user's own topic.
  final Map<PushTopic?, VoidCallback> _subscriptions = {};

  /// Wires notification taps; [onOpenThread] gets a post id.
  Future<void> start({
    required void Function(String postId) onOpenThread,
  }) async {
    _onOpenThread = onOpenThread;
    _stopTaps ??= _live.onTap(_handleTap);
    final launch = await _live.initialTapData();
    if (launch != null) _handleTap(launch);
  }

  Future<void> onSignedIn() async {
    if (_signedIn) return;
    _signedIn = true;
    final targetId = await _registrar.register(
      await _installId(),
      providerId: AppConfig.appwritePushProviderId,
    );
    // Messages addressed to the user need no target; topics do.
    if (targetId != null) await _topics.syncOnRegister(targetId);

    await _subscribe(null);
    for (final topic in PushTopic.configured) {
      if (targetId != null && await _topics.isEnabled(topic)) {
        await _subscribe(topic);
      }
    }
  }

  /// Follows a topic switch in settings: the server-side subscriber was
  /// already changed by [TopicSubscriptions.setEnabled].
  Future<void> applyTopic(PushTopic topic, bool enabled) async {
    if (!_signedIn) return;
    if (enabled) {
      await _subscribe(topic);
    } else {
      _subscriptions.remove(topic)?.call();
    }
  }

  Future<void> onSignedOut() async {
    _signedIn = false;
    _subscriptions.clear();
    // Close before the target goes: it also stops background delivery,
    // including subscriptions saved by an earlier run.
    _push?.close();
    await _registrar.unregister();
  }

  Future<void> _subscribe(PushTopic? topic) async {
    if (_subscriptions.containsKey(topic)) return;
    try {
      _subscriptions[topic] = await _live.subscribe(
        topic == null ? null : [topic.topicId],
      );
    } catch (error) {
      debugPrint('Appwrite Push subscribe failed (${topic?.topicId}): $error');
    }
  }

  void _handleTap(Map<String, dynamic> data) {
    final postId = data['postId'];
    if (postId is String && postId.isNotEmpty) _onOpenThread?.call(postId);
  }

  void dispose() {
    _stopTaps?.call();
    _stopTaps = null;
  }

  /// A stable per-install identifier for the target. Appwrite Push does not
  /// use it, but it must be unique, and reusing it keeps re-registration an
  /// in-place update.
  static Future<String> _prefsInstallId() async {
    const key = 'refetch_push_install_id';
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(key);
    if (existing != null) return existing;
    final id = ID.unique();
    await prefs.setString(key, id);
    return id;
  }
}
