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

## Releasing

Both stores are driven by [fastlane](https://fastlane.tools), configured per
platform under `android/fastlane/` and `ios/fastlane/`. Store listing text lives
in `fastlane/metadata/` alongside the app.

```bash
cd android && bundle install     # or: cd ios && bundle install
bundle exec fastlane lanes
```

Shared lane names: `build` (no upload), `beta` (Play open testing / TestFlight),
`release` (Play production / App Store review), plus `upload_metadata`,
`upload_screenshots`, `upload_listing`, `download_metadata` and `screenshots`.
Android also has `internal` for the Play internal track.

Everything project-specific is read from environment variables, so no secrets
are committed — set them in your CI provider or a local, gitignored `.env`:

- **Android** — `APP_IDENTIFIER`, plus `PLAY_STORE_JSON_KEY_PATH` or
  `PLAY_STORE_JSON_KEY_DATA`. Release signing still comes from
  `android/key.properties`. The build/upload logic lives in
  [fastlane-plugin-play_publisher](https://github.com/popupbits/fastlane-plugin-play_publisher),
  which documents the optional vars (`SUPPLY_RELEASE_STATUS=draft` for a
  first-ever release, `SKIP_FLUTTER_BUILD=1`, …).
- **iOS** — `APP_IDENTIFIER`, `APPLE_ID`, `TEAM_ID`, `ITC_TEAM_ID`,
  `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
  `APP_STORE_CONNECT_KEY_CONTENT` (base64 `.p8`), and `MATCH_GIT_URL` /
  `MATCH_PASSWORD` for the private
  [match](https://docs.fastlane.tools/actions/match/) certificates repo.
  `fastlane fetch_apple_info` prints your `ITC_TEAM_ID`.

## License

[MIT](LICENSE) — consistent with the
[Refetch](https://github.com/refetch-io/refetch) project.
