# Store screenshots

Every store listing image is built by a GitHub workflow and arrives as a pull
request (ported from momo-pasal). The copy and styling live in
`headlines.json`.

| Step | What runs |
|---|---|
| Capture | `integration_test/screenshot_test.dart` with `flutter drive`, on a CI emulator or simulator. It reads the live feed from Appwrite; analytics is compiled out. |
| Job | `tool/screenshot_job.dart` turns `headlines.json` into a moksha job |
| Render | [moksha](https://github.com/lohanidamodar/moksha): device frame, Refetch purple background, Poppins headline, Inter subhead, at the exact store size, checked against store rules (no alpha, Play's 2:1 limit, Apple sizes) |
| Review | the workflow opens a PR; the diff is the review |

## The workflows

Manual only (Actions › Screenshots (Android) / Screenshots (iOS)):

| Family | Captured on | Output | Goes to |
|---|---|---|---|
| Android phone | `pixel_6` emulator, API 34 | 1080x1920 | `android/fastlane/metadata/android/<locale>/images/phoneScreenshots/` |
| iPhone 6.9" | iPhone 17 Pro Max simulator | 1320x2868 | `ios/fastlane/screenshots/framed/<locale>/iphone_*.png` |
| iPad 13" | iPad Pro 13" simulator | 2064x2752 | `ios/fastlane/screenshots/framed/<locale>/ipad_*.png` |

Those are the folders the fastlane `upload_screenshots` / `upload_listing`
lanes read, so a merged PR is in the release path.

## Changing the copy or the screens

Edit `headlines.json`; scene ids match the names the test captures
(`top`, `thread`, `new`, `account`). Add a screen in the test and a scene here.

## Locally

```sh
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  --dart-define=ANALYTICS_PROPERTY_ID= -d <device>
dart run tool/screenshot_job.dart --asset-type android-phone-screenshot \
  --size-id android-phone --out build/job.json
# in a moksha checkout (clone it on Linux/WSL: a Windows checkout's CRLF
# line endings break its scripts)
npm ci && npm run render -- --job <app>/build/job.json \
  --images <app>/build/screenshots --out <app>/build/rendered
```
