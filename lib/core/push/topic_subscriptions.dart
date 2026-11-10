import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';

import 'push_target_store.dart';
import 'push_topic.dart';

/// Subscribes/unsubscribes the device's push target to Appwrite Messaging topics
/// using the **client** `Messaging.createSubscriber` / `deleteSubscriber` APIs —
/// no backend function required.
class TopicSubscriptions {
  TopicSubscriptions(this._messaging, this._targetStore, this._prefs);

  final Messaging _messaging;
  final PushTargetStore _targetStore;
  final PushPreferences _prefs;

  /// Persists the choice and applies it immediately if a target exists; if not,
  /// it is applied on the next registration via [syncOnRegister].
  Future<void> setEnabled(PushTopic topic, bool enabled) async {
    await _prefs.setEnabled(topic, enabled);
    if (!topic.isConfigured) return;
    final targetId = await _targetStore.read();
    if (targetId == null) return;
    if (enabled) {
      await _subscribe(topic, targetId);
    } else {
      await _unsubscribe(topic, targetId);
    }
  }

  /// The user's saved choice for [topic] (default on).
  Future<bool> isEnabled(PushTopic topic) => _prefs.isEnabled(topic);

  /// Applies saved preferences to a freshly-registered [targetId]. Best-effort:
  /// a failure on one topic does not block the others.
  Future<void> syncOnRegister(String targetId) async {
    for (final topic in PushTopic.configured) {
      try {
        if (await _prefs.isEnabled(topic)) {
          await _subscribe(topic, targetId);
        }
      } catch (error) {
        debugPrint('Topic subscribe failed for ${topic.topicId}: $error');
      }
    }
  }

  /// Subscriber id, unique per (target, topic). Appwrite subscriber ids are
  /// project-unique, so the target id alone collides across topics (the second
  /// topic 409s). The id is deterministic so unsubscribe matches, and stays
  /// within Appwrite's 36-char id limit.
  String _subscriberId(String targetId, PushTopic topic) {
    final id = '${targetId}_${topic.name}';
    return id.length <= 36 ? id : id.substring(0, 36);
  }

  Future<void> _subscribe(PushTopic topic, String targetId) async {
    try {
      await _messaging.createSubscriber(
        topicId: topic.topicId,
        subscriberId: _subscriberId(targetId, topic),
        targetId: targetId,
      );
    } on AppwriteException catch (e) {
      if (e.code != 409) rethrow; // 409 = already subscribed
    }
  }

  Future<void> _unsubscribe(PushTopic topic, String targetId) async {
    try {
      await _messaging.deleteSubscriber(
        topicId: topic.topicId,
        subscriberId: _subscriberId(targetId, topic),
      );
    } on AppwriteException catch (e) {
      if (e.code != 404) rethrow; // 404 = not subscribed
    }
  }
}
