/// The app's analytics, behind an interface so the backend can be swapped or
/// switched off. The app only ever talks to an [AnalyticsService]; today the
/// implementation is Appwrite Analytics ([AppwriteAnalyticsService]), wrapped
/// in [ConsentedAnalytics] so the user's choice in Account always wins.
///
/// Privacy rules every implementation keeps:
///  * no user id, email, name or free text (titles, comments) in events;
///  * ids of public stories are fine — they are public anyway;
///  * nothing is sent while the user has analytics turned off.
abstract interface class AnalyticsService {
  /// Begin automatic events (app foregrounded/backgrounded).
  void start();

  /// Stop automatic events. Explicit calls after this are dropped too.
  void stop();

  /// A screen came into view. [screen] is a route name such as `thread`.
  void screenView(String screen, {Map<String, Object?>? props});

  /// A custom event. Names are `snake_case` (see [AnalyticsEvents]).
  void track(String name, {Map<String, Object?>? props});
}

/// Event names, kept stable so their history stays comparable.
abstract final class AnalyticsEvents {
  static const feedLoaded = 'feed_loaded';
  static const feedLoadFailed = 'feed_load_failed';
  static const threadLoadFailed = 'thread_load_failed';
  static const storyOpened = 'story_opened';
  static const articleOpened = 'article_opened';
  static const storyShared = 'story_shared';
  static const voteCast = 'vote_cast';
  static const commentPosted = 'comment_posted';
  static const storySubmitted = 'story_submitted';
  static const signedIn = 'signed_in';
  static const signedUp = 'signed_up';
  static const signInFailed = 'sign_in_failed';
  static const signedOut = 'signed_out';
  static const settingChanged = 'setting_changed';
}

/// Does nothing. Used when no analytics property is configured, and in tests.
class NoopAnalytics implements AnalyticsService {
  const NoopAnalytics();

  @override
  void start() {}

  @override
  void stop() {}

  @override
  void screenView(String screen, {Map<String, Object?>? props}) {}

  @override
  void track(String name, {Map<String, Object?>? props}) {}
}

/// Forwards to [delegate] only while the user allows analytics.
///
/// Until the saved choice is known ([enabled] is null) events are held, up to
/// [maxPending], so the first screen view isn't lost at startup; they are sent
/// if the choice turns out to be "on" and dropped if it is "off". Turning it
/// off stops the automatic events at once and drops everything after.
class ConsentedAnalytics implements AnalyticsService {
  ConsentedAnalytics(this.delegate, {this._enabled = true});

  static const maxPending = 20;

  final AnalyticsService delegate;
  bool? _enabled;
  bool _started = false;
  final List<void Function()> _pending = [];

  /// Null while the saved choice hasn't been read yet.
  bool? get enabled => _enabled;

  set enabled(bool? value) {
    if (value == _enabled) return;
    final wasOn = _enabled == true;
    _enabled = value;
    if (value == true) {
      if (_started && !wasOn) delegate.start();
      for (final send in _pending) {
        send();
      }
    } else if (value == false && _started && wasOn) {
      delegate.stop();
    }
    if (value != null) _pending.clear();
  }

  void _send(void Function() send) {
    switch (_enabled) {
      case true:
        send();
      case null:
        if (_pending.length < maxPending) _pending.add(send);
      case false:
        break;
    }
  }

  @override
  void start() {
    _started = true;
    if (_enabled == true) delegate.start();
  }

  @override
  void stop() {
    _started = false;
    delegate.stop();
  }

  @override
  void screenView(String screen, {Map<String, Object?>? props}) =>
      _send(() => delegate.screenView(screen, props: props));

  @override
  void track(String name, {Map<String, Object?>? props}) =>
      _send(() => delegate.track(name, props: props));
}

/// Props as the endpoint wants them: non-null values only, at most
/// [maxPairs] pairs (the API takes 32 flattened entries; one pair is left
/// for the `screen` key the screen-view helper adds).
Map<String, Object> cleanProps(
  Map<String, Object?>? props, {
  int maxPairs = 15,
}) {
  if (props == null) return const {};
  final out = <String, Object>{};
  for (final entry in props.entries) {
    final value = entry.value;
    if (value == null) continue;
    if (out.length >= maxPairs) break;
    out[entry.key] = value;
  }
  return out;
}
