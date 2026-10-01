# Moneef — Flutter app

See the [root README](../README.md) for what Moneef is, the architecture, and
how to build the whole project. This file covers app-specific tooling only.

## Screenshots

The README grids in `docs/screenshots/` are built from the screenshot goldens.
If the UI has changed, refresh the goldens first:

```sh
flutter test test/screenshots --update-goldens --tags screenshots
```

## Android builds

Install JDK 21 alongside Flutter and the Android SDK. The project's
`android/gradle/gradle-daemon-jvm.properties` selects an installed JDK 21 for
Gradle, even when Flutter uses a newer Java version bundled with Android Studio.

The launcher name is Moneef. After changing native icons or launch resources,
stop the app and run `flutter run` again; hot reload does not replace these
Android resources. The application ID stays `io.moneef.mobile_app`, so normal
updates preserve the existing installation and data.

## Branding

The logo source is `assets/branding/moneef-icon.svg`. The Flutter painter in
`lib/widgets/branding/moneef_logo.dart` and the Android icon resources were
exported from it by hand.

Startup checks:

```sh
flutter test test/widgets/startup_splash_test.dart test/e2e/boot_e2e_test.dart
flutter test test/screenshots/startup_screenshots_test.dart
```