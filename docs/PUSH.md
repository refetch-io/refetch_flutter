# Push notifications

Each platform uses the transport Appwrite recommends for it:

| Platform | Transport | Appwrite provider | Code |
|---|---|---|---|
| Android | **Appwrite Push** (Appwrite's own MQTT broker, no Firebase) | `6af28d0b00167c6b3005` | `lib/core/push/appwrite_push_channel.dart` |
| iOS | **APNs** through the [`push`](https://pub.dev/packages/push) plugin | `6a8a7cc54e645db3829c` | `lib/core/push/push_notification_service.dart` |

The ids live in `AppConfig`. Senders don't change: `backend/functions` call
`messaging.createPush` with `users` (replies, published) or a topic (weekly
digest), and Appwrite picks the route.

## Android: Appwrite Push

These steps follow the [Appwrite Push docs](https://appwrite.io/docs/products/messaging/appwrite-push).

1. After sign-in the app creates an Appwrite push target on the Appwrite provider.
   - Its `identifier` is a per-install id, which Appwrite Push doesn't use.
   - A topic needs a target before the app can subscribe to it.
   - Saved topic choices are applied to that target as Messaging subscribers.
2. `Push.subscribe` opens background subscriptions:
   - `null`: the user's own `users/<id>` topic, which carries every message addressed to the user.
   - each enabled topic.

   The SDK posts the notification, with `notifyInForeground` so it also shows while the app is open, as FCM did. Taps report the message's `data`, and `postId` opens the thread.
3. Once the app is closed, the SDK's job and alarm wake it to reconnect. The interval runs from about 15 to 60 seconds, and about 9 minutes in Doze. The broker replays anything missed, kept for up to 7 days.
4. Sign-out calls `Push.close()`, which also stops background delivery, then deletes the target.

Manifest (`android/app/src/main/AndroidManifest.xml`):
- **Kept:** the SDK's `PushJobService`, `PushAlarmReceiver`, `PushBootReceiver`, `PushOpenActivity` and `RECEIVE_BOOT_COMPLETED`.
- **Removed:**
  - `PushService` and `FOREGROUND_SERVICE(_REMOTE_MESSAGING)`. The app never calls `setForeground`, so it needs no Play foreground-service declaration.
  - `flutter_background_service`, which the SDK uses only off Android.
  - The `push` plugin's FCM receiver and service, Firebase Messaging's service and its exported `FirebaseInstanceIdReceiver`, and `FirebaseInitProvider`. The Firebase libraries still ship, because the `push` plugin depends on them, but nothing starts them.
- **Small icon:** `io.appwrite.flutter.push.notification_icon` points at `@drawable/ic_launcher_monochrome`.

Firebase is gone from the Android build: no `google-services` plugin, and the
release workflow no longer decodes `google-services.json`. The
`ANDROID_GOOGLE_SERVICES_JSON` secret is unused and can be deleted.

## iOS: APNs

Unchanged. The `push` plugin registers the APNs token as a target on the APNs
provider. Appwrite Push on Flutter iOS only receives while the app runs, which
is why Appwrite recommends APNs there.

## Known limitation: signed in on both platforms

Appwrite routes push per user (server `Workers/Messaging.php`). Once a user has
any Appwrite Push target, their APNs devices get a generic **"New message"**
wake-up instead of the full notification. With the Apple SDK, a Notification
Service Extension would fetch the real message, but a Flutter app has no such
extension.

The result for each kind of user:
- iOS only, or Android only: full notifications.
- Signed in on both an iPhone and an Android phone: full notifications on Android, "New message" on the iPhone. Tapping it opens the app.

Accepted on 2026-11-09. The fix, if needed, is a Swift Notification Service
Extension built on `sdk-for-apple`. It needs an App Group, a per-install
`setPushClientId`, and a way to hand it a session.

## Verified

On 2026-11-10, a debug build on a CPH1989 (Android 11), signed in with the app in
the background, received a Console push to the user: it was posted on the SDK's
`appwrite-push` channel with the Refetch icon, and tapping it opened the app. The
`postId` deep link on tap is covered by the unit tests, not by a live message.
