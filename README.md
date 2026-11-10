# Refetch — Mobile & Desktop App

> The front page for builders. Open-source alternative to YC-controlled HN,
> featuring curated tech news, discussions, and community-driven content.

The official **Flutter** client for [Refetch](https://refetch.io), bringing the
feed, threads, voting, and notifications to Android, iOS, macOS, Windows, and
Linux on top of the same [Appwrite](https://appwrite.io) backend as the web app.

- 🌐 Web app: <https://refetch.io>
- 🧩 Web project & backend: <https://github.com/refetch-io/refetch>

## Features

- 📰 Curated feed — Top, New, Show, and Mines tabs
- 💬 Threaded comments with replies
- ⬆️ Voting on posts and comments
- ✍️ Share links, with a note that starts the discussion
- 📤 Share any story's discussion to other apps
- 🔐 Email/password accounts
- 🔔 Push notifications — replies and an opt-in weekly digest
- 🌗 The refetch.io look, light and dark

## Architecture

A **hybrid client** on the same [Appwrite](https://appwrite.io) project as the
web app:

- **Reads** (feeds, stories, comments) come straight from Appwrite TablesDB,
  which the public can read, with the same queries refetch.io runs.
- **Writes and private data** (votes, comments, submissions, your own votes)
  go through the refetch.io app API, `/api/app/*`, authenticated with a
  short-lived Appwrite JWT. It runs the website's own server code, so rate
  limits, counters and notifications stay in one place. See
  [`docs/APP_API.md`](https://github.com/refetch-io/refetch/blob/main/docs/APP_API.md)
  in the web repo.
- **Auth** is the Appwrite Dart SDK (email/password sessions).
- **Push** is Appwrite Push (Appwrite's own provider, no Firebase) on Android
  and APNs through the [`push`](https://pub.dev/packages/push) plugin on iOS.
  See [`docs/PUSH.md`](docs/PUSH.md).
- **Analytics** is Appwrite Analytics, behind `AnalyticsService`
  (`lib/core/analytics/`). Events are anonymous, carry no user id or text the
  person wrote, and stop when the switch in Account › Privacy is off. The
  property id is `AppConfig.analyticsPropertyId`; build with
  `--dart-define=ANALYTICS_PROPERTY_ID=` (empty) to compile analytics out.

Built with Flutter, Riverpod, go_router, `http`, and the `appwrite` Dart SDK.
Brand values and where they came from: [`docs/BRANDING.md`](docs/BRANDING.md).

## Getting started

```bash
flutter pub get
flutter run            # pick a device, or e.g. flutter run -d windows
```

The feed works out of the box against the Refetch backend. Push notifications
are optional and disabled until configured — see [`backend/`](backend/README.md)
and the topic/provider ids in `lib/core/config/app_config.dart`.

Release signing is read from `android/key.properties` (gitignored); see
`android/key.properties.example`.

Launcher icons, the splash and the Play listing art are generated from the
logo mark (see [`docs/BRANDING.md`](docs/BRANDING.md#regenerating-the-art)):

```bash
python tool/render_brand_assets.py
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Releases are cut by the maintainers from **Actions → Android Release / iOS
Release**; each workflow file documents the secrets it needs.

## License

[MIT](LICENSE) — consistent with the
[Refetch](https://github.com/refetch-io/refetch) project.
