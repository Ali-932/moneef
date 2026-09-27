# `mobilebridge/` — gomobile bindings for Flutter

This package exposes the Moneef Go core as a JNI-compatible Android library
(`.aar`). The Flutter Android app calls into the library through a Kotlin
`MethodChannel` shim; iOS is not yet wired.

> **Looking for the full API reference?** Every function's request /
> response JSON schema, error catalog, Kotlin handler, and Dart caller is
> documented in **[API.md](./API.md)**. This README covers build setup and
> a 60-second usage example only.

## Build constraints

Every file under `mobilebridge/` is gated by `//go:build android || smoke`. Default
builds (`go build ./...`, `go test ./...`) ignore this package entirely. The
`smoke` tag builds it on the host for the binding tests and the Flutter e2e
library:

```bash
go test -tags smoke ./mobilebridge/
go build -tags smoke -buildmode=c-shared -o build/libmoneef_e2e.so ./mobilebridge/_e2e/
```

To verify the source compiles for Android without invoking `gomobile`:

```bash
GOOS=android CGO_ENABLED=0 GOARCH=arm64 go build ./mobilebridge/...
```

## Producing the `.aar`

Install `gomobile` once:

```bash
go install golang.org/x/mobile/cmd/gomobile@latest
go install golang.org/x/mobile/cmd/gobind@latest
gomobile init
```

Then bind:

```bash
gomobile bind -target=android -androidapi 21 -o build/moneef.aar ./mobilebridge
```

Output:

- `build/moneef.aar` — drop into `android/app/libs/` of the Flutter project.
- `build/moneef-sources.jar` — sources for Android Studio's debugger.

## Exported API

All signatures use only types gomobile can marshal: `string`, `[]byte`,
`int64`, `error`, `bool`. Numeric IDs are `int64` (Go's `uint` is not
bridgeable). Complex payloads pass as JSON bytes.

| Function | Description |
|---|---|
| `Init(dbPath string, profileID int64) error` | Open SQLite, run migrations, seed missing icon keywords offline, refresh automatic icons, and optionally set the active profile. Call once at startup. `profileID = 0` if not yet known (first run). |
| `Shutdown() error` | Close the DB connection cleanly. Safe to call before exit. |
| `SetProfileID(id int64) error` | Switch the active profile without re-opening the DB. |
| `Setup(payload []byte) ([]byte, error)` | First-run user + profile + settings creation. Stores the new profile id automatically. Returns `{profile_id, user_id, first_name, last_name, currency_code, language}`. |
| `CreateTransaction(payload []byte) ([]byte, error)` | |
| `ListTransactions(payload []byte) ([]byte, error)` | Inline pagination. See `ListTransactionsRequest`. |
| `GetTransaction(id int64) ([]byte, error)` | |
| `UpdateTransaction(id int64, payload []byte) ([]byte, error)` | |
| `DeleteTransaction(id int64) error` | |
| `ListRecurrences() ([]byte, error)` | |
| `RecurrenceTimeline() ([]byte, error)` | |
| `UpdateRecurrence(id int64, payload []byte) error` | Save a recurring payment's name, schedule, status, merchant, and notes. |
| `DeleteRecurrence(id int64) error` | |
| `ListCategories(payload []byte) ([]byte, error)` | |
| `CreateCategory(payload []byte) ([]byte, error)` | |
| `UpdateCategory(id int64, payload []byte) error` | |
| `DeleteCategory(id int64) error` | |
| `Dashboard(payload []byte) ([]byte, error)` | |
| `Analysis(payload []byte) ([]byte, error)` | If `currency` is empty, resolved from user settings. |
| `Patterns() ([]byte, error)` | |
| `RefreshPatterns(payload []byte) ([]byte, error)` | |
| `GetProfile() ([]byte, error)` | |
| `UpdateProfile(payload []byte) error` | |
| `GetSettings() ([]byte, error)` | |
| `UpdateSettings(payload []byte) error` | |
| `ListCurrencies() ([]byte, error)` | Needs `Init` only, no active profile. |
| `ListExchangeRates(payload []byte) ([]byte, error)` | If `base` is empty, resolved from user settings. |
| `UpsertExchangeRate(payload []byte) error` | Writes the pair and its inverse. |
| `FetchExchangeRates() error` | Uses `exchange_rate_api_key` from settings. |
| `ActiveProfileID() int64` | Zero means setup or restore is needed. |
| `CreateBackup(path string) ([]byte, error)` | Writes a local ZIP snapshot, returns its manifest. |
| `RestoreBackup(path string) ([]byte, error)` | Replaces the database from an archive, returns its manifest. |

## Money / decimal serialization

`pkg/types.Money` (alias for `shopspring/decimal.Decimal`) marshals to JSON
as a **string**, e.g. `"10.50"`. The Flutter side must use
[`package:decimal`](https://pub.dev/packages/decimal) and `Decimal.parse`:

```dart
final amount = Decimal.parse(json['amount'] as String);
```

Do NOT decode amounts as `num` / `double` — you will lose precision.

## Error handling

Go errors propagate to the Kotlin side as `java.lang.Exception`. On the
Flutter side they surface as `PlatformException` with the original Go error
message in `details`. Sentinel errors are stable strings and may be matched
on:

- `mobile: Init has not been called`
- `mobile: Init has already been called`
- `mobile: profile id is not set; call SetProfileID or pass it to Init`
- `mobile: invalid JSON payload: <encoder error>`

## Android and Dart wiring

The real bridge lives in the Flutter app. Use it as the reference rather than
copying snippets:

- `mobile_app/android/app/src/main/kotlin/io/moneef/mobile_app/MoneefBridge.kt`:
  `moneef/api` channel, dispatches calls to the generated `Mobilebridge` class on a
  worker thread.
- `mobile_app/android/app/src/main/kotlin/io/moneef/mobile_app/LocalBackups.kt`:
  `moneef/backups` channel.
- `mobile_app/lib/services/native_api.dart`: Dart caller.

`Mobilebridge` is the auto-generated Java class that wraps the Go package. Method
names are lower-camel-cased (`Init` → `init`, `CreateTransaction` →
`createTransaction`).

## Out-of-process smoke test

There is also a Go-only driver under `mobilebridge/_smoke/` for validating the
JSON contract without an Android device:

```bash
go run -tags=smoke ./mobilebridge/_smoke/
```

It opens a temp SQLite file, runs `Init` → `Setup` → `CreateTransaction` →
`ListTransactions` and prints the round-trip JSON. Useful for catching
regression in the shim without an Android NDK present. Note: the `smoke` tag
builds the package on the host without gomobile, so it is a *contract* test,
not a JNI test.
