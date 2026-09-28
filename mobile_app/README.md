# Moneef

Moneef personal finance tracker

## Screenshots

Six app screens with sample data. The grid follows your light or dark theme.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/screenshot-grid-dark.png">
  <img src="docs/screenshots/screenshot-grid-light.png" alt="Moneef home, transactions, add transaction, insights, spending analysis, and recurring payments in a three-column grid" width="1440">
</picture>

[Light grid](docs/screenshots/screenshot-grid-light.png) · [Dark grid](docs/screenshots/screenshot-grid-dark.png)

To regenerate the grids from the saved screenshot goldens, install `rsvg-convert`
from librsvg and run:

```sh
python3 tool/generate_screenshot_grid.py
python3 tool/generate_screenshot_grid.py --check
```

If the goldens are missing or the UI has changed, refresh them first:

```sh
flutter test test/screenshots --update-goldens --tags screenshots
```

## Android builds

Install JDK 21 alongside Flutter and the Android SDK. The project's
`android/gradle/gradle-daemon-jvm.properties` selects an installed JDK 21 for
Gradle, even when Flutter uses a newer Java version bundled with Android Studio.

From this directory, run:

```sh
flutter pub get
flutter run
```

The launcher name is Moneef. After changing native icons or launch resources,
stop the app and run `flutter run` again; hot reload does not replace these
Android resources. The application ID stays `io.moneef.mobile_app`, so normal
updates preserve the existing installation and data.

## Branding

The approved Fold M source is `assets/branding/moneef-icon.svg`. To regenerate
the app logo and Android icon sizes, install `rsvg-convert` from librsvg and run:

```sh
python3 tool/generate_branding.py
python3 tool/generate_branding.py --check
```

Startup checks:

```sh
flutter test test/widgets/startup_splash_test.dart test/e2e/boot_e2e_test.dart
flutter test test/screenshots/startup_screenshots_test.dart
```
