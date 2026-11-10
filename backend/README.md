# Refetch push-notification backend functions

Appwrite Functions that send push notifications for the Refetch app, via the
Appwrite **Messaging** API. They deploy to the same Appwrite project as the app
(`63ef1792594ff4f50de2`) and can live here or be merged into the
[`refetch-io/refetch`](https://github.com/refetch-io/refetch) `functions/`
directory — they follow the same conventions (Node 18+, ESM, `node-appwrite`).

All database access uses the **TablesDB** service (not the legacy `Databases`
service), matching the rest of the refetch backend.

| Function | Trigger | Purpose |
|---|---|---|
| `notify-reply` | event: comment document `create` | Notify the parent-comment author (reply) or post author (top-level comment). Skips self-replies. |
| `notify-published` | event: post document `update` | Notify the author when their post becomes `enhanced = true`. |
| `weekly-digest` | CRON (weekly) | Push the week's top stories to the `weekly-digest` topic. |

Topic **subscription** is handled client-side by the app via the Appwrite
`Messaging.createSubscriber` API (toggled per topic in the profile screen), so no
`subscribe` function is needed.

## Transport

Two Appwrite Messaging providers deliver to the app (see `../docs/PUSH.md`):

- **Appwrite Push provider** → Android, over Appwrite's own broker (no FCM).
- **APNS provider** → iOS (device registers its APNS token; upload your APNS
  `.p8` auth key to the Appwrite APNS provider).

`messaging.createPush` targets users (`notify-*`) or a topic (`weekly-digest`); Appwrite
routes each user's messages to the right provider.

## Shared env (set on every function)

```
APPWRITE_API_KEY=<server key with messaging.write, documents.read, users.read>
APPWRITE_DATABASE_ID=688f787e002c78bd299f
APPWRITE_POSTS_COLLECTION_ID=688f78a20022f61836ff
APPWRITE_COMMENTS_COLLECTION_ID=68993e6c003af0fe657f
DIGEST_TOPIC_ID=<messaging topic id>       # used by weekly-digest (weekly-digest topic)
DIGEST_COUNT=5                              # optional
```

`APPWRITE_FUNCTION_API_ENDPOINT` and `APPWRITE_FUNCTION_PROJECT_ID` are injected
by the Appwrite runtime.

## Tests

`notify-reply` has unit tests for its pure recipient-resolution logic:

```
cd backend/functions/notify-reply && node --test
```

Set the provider and topic ids in `lib/core/config/app_config.dart` and deploy
each function to the Refetch Appwrite project with the env and triggers above.
