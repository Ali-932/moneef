# Moneef

[![CI](https://github.com/Ali-932/moneef/actions/workflows/ci.yml/badge.svg)](https://github.com/Ali-932/moneef/actions/workflows/ci.yml)

Moneef is a deliberately minimal personal finance tracker for Android. All
data stays on the phone in a local SQLite database: no account, no server.
The only network call is the optional exchange-rate update.

## Screenshots

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="mobile_app/docs/screenshots/screenshot-grid-dark.png">
  <img src="mobile_app/docs/screenshots/screenshot-grid-light.png" alt="Moneef home, transactions, add transaction, insights, spending analysis, and recurring payments in a three-column grid" width="1440">
</picture>

[Light grid](mobile_app/docs/screenshots/screenshot-grid-light.png) · [Dark grid](mobile_app/docs/screenshots/screenshot-grid-dark.png)

## Features

- Transactions: income/expense, split across multiple categories
- Accounts: transfers between accounts, manual balance correction, currency exchange
- Multi-currency, with the USD rate frozen on each transaction
- Recurring payments, including installments with a total and amount paid
- Insights: spending charts, period comparison
- Spending pattern detection
- Local backups

## Architecture

```
Flutter UI (mobile_app/, Riverpod + go_router + freezed)
    │  Kotlin MethodChannels: moneef/api, moneef/backups
    ▼
mobilebridge/ (gomobile AAR — JSON bytes in/out, int64 IDs)
    │
    ▼
Go services: internal/<feature>/{dto,service,repository}
    │
    ▼
SQLite via GORM (github.com/glebarez/sqlite — pure Go, no cgo)
```

There is no HTTP server and no backend to run. The Go core is compiled into
an Android library (`.aar`) and called in-process from Flutter. Full API
surface: `mobilebridge/API.md`.

## Prerequisites

- Go 1.25 (see `go.mod`)
- Flutter, stable channel
- Android SDK + NDK, with `ANDROID_HOME` and `ANDROID_NDK_HOME` set
- JDK 21 (see `mobile_app/README.md` for Gradle's JDK selection)
- `gomobile`:
  ```bash
  go install golang.org/x/mobile/cmd/gomobile@latest
  gomobile init
  ```

## Building

Go core and bridge, from the repo root:

```bash
go build ./...
gomobile bind -target=android -androidapi 21 -o mobile_app/android/app/libs/moneef.aar ./mobilebridge
```

The `.aar` is git-ignored. `flutter run` links this prebuilt file, so rebuild
it after any change under `mobilebridge/` or `internal/`.

Then run the app:

```bash
cd mobile_app
flutter pub get
flutter run
```

## Tests

```bash
go test ./...                                                # Go unit tests
go test -tags smoke ./mobilebridge/                          # bridge tests
GOOS=android CGO_ENABLED=0 GOARCH=arm64 go build ./mobilebridge/...  # Android compile check

# Flutter e2e tests load the Go core over dart:ffi; build that shared lib first
go build -tags smoke -buildmode=c-shared -o build/libmoneef_e2e.so ./mobilebridge/_e2e/

cd mobile_app
flutter test --exclude-tags screenshots
```

## Exchange rates

Currency conversion rates can be entered manually, or fetched automatically
with a free API key from [exchangerate-api.com](https://www.exchangerate-api.com/),
entered in the app's Settings. The key is stored in the local database and is
only sent to exchangerate-api.com.

## License

MIT — see `LICENSE`.
