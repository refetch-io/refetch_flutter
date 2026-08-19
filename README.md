# Refetch — Mobile & Desktop App

> Open-source alternative to YC-controlled HN, featuring curated tech news,
> discussions, and community-driven content.

The official **Flutter** client for [Refetch](https://refetch.io), bringing the
feed, threads, voting, and notifications to Android, iOS, macOS, Windows, and
Linux on top of the same [Appwrite](https://appwrite.io) backend as the web app.

- 🌐 Web app: <https://refetch.io>
- 🧩 Web project & backend: <https://github.com/refetch-io/refetch>

## Features

- 📰 Curated feed — Top, New, Show, and Mines tabs
- 💬 Threaded comments with replies
- ⬆️ Voting on posts and comments
- ✍️ Submit links or "Show" posts
- 🔐 Email/password accounts
- 🔔 Push notifications — replies and an opt-in weekly digest
- 🌗 Material 3 light/dark theming

## Architecture

A **hybrid client** that reuses the existing Refetch backend: **auth** goes
through the Appwrite Dart SDK (sessions + JWT), while **reads and mutations** go
through the `refetch.io` REST API authenticated with that JWT. **Push** uses FCM
on Android and APNS directly on iOS (no Firebase on iOS) via the
[`push`](https://pub.dev/packages/push) plugin.

Built with Flutter, Riverpod, go_router, `http`, and the `appwrite` Dart SDK.

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

Launcher icons are generated from `assets/icon/` (sources also kept as SVG):

```bash
dart run flutter_launcher_icons
```

## License

[MIT](LICENSE) — consistent with the
[Refetch](https://github.com/refetch-io/refetch) project.
