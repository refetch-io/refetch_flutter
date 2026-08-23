import 'package:shared_preferences/shared_preferences.dart';

/// Persists the Appwrite push-target id so it survives restarts and can be
/// updated (on token refresh) or deleted (on sign-out).
///
/// The provider the target was created against is stored alongside it:
/// `updatePushTarget` can change a target's identifier but never its provider,
/// so a target created under a different provider has to be replaced.
abstract class PushTargetStore {
  Future<String?> read();

  /// Provider id the stored target was created against, `null` if the target
  /// predates provider tracking or was created without one.
  Future<String?> readProviderId();

  Future<void> write(String targetId, {String? providerId});

  Future<void> clear();
}

/// [PushTargetStore] backed by `shared_preferences`.
class PrefsPushTargetStore implements PushTargetStore {
  static const _key = 'refetch_push_target_id';
  static const _providerKey = 'refetch_push_target_provider_id';

  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<String?> readProviderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_providerKey);
  }

  @override
  Future<void> write(String targetId, {String? providerId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, targetId);
    if (providerId == null || providerId.isEmpty) {
      await prefs.remove(_providerKey);
    } else {
      await prefs.setString(_providerKey, providerId);
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_providerKey);
  }
}

/// In-memory store, useful for tests.
class InMemoryPushTargetStore implements PushTargetStore {
  String? _value;
  String? _providerId;

  InMemoryPushTargetStore([this._value, this._providerId]);

  @override
  Future<String?> read() async => _value;

  @override
  Future<String?> readProviderId() async => _providerId;

  @override
  Future<void> write(String targetId, {String? providerId}) async {
    _value = targetId;
    _providerId = providerId;
  }

  @override
  Future<void> clear() async {
    _value = null;
    _providerId = null;
  }
}
