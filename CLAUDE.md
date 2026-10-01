# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

**Go core**
```bash
go build ./...              # build the core (mobilebridge/ excluded, see Build tags)
go test ./...                # unit tests
```

**Mobile binding (`mobilebridge/`)**
```bash
go test -tags smoke ./mobilebridge/                         # binding tests
GOOS=android CGO_ENABLED=0 GOARCH=arm64 go build ./mobilebridge/...  # Android compile check
gomobile bind -target=android -androidapi 21 -o mobile_app/android/app/libs/moneef.aar ./mobilebridge
go build -tags smoke -buildmode=c-shared -o build/libmoneef_e2e.so ./mobilebridge/_e2e/  # needed by Flutter e2e tests
```

**Flutter app (`mobile_app/`)**
```bash
flutter pub get
flutter run
flutter test --exclude-tags screenshots   # unit/widget/e2e tests
flutter test test/screenshots --update-goldens --tags screenshots   # refresh screenshot goldens
```

The `.aar` `flutter run` links is prebuilt and git-ignored — rebuild it with
`gomobile bind` (above) after any change under `mobilebridge/` or `internal/`
before handing the app back over.

## Architecture

Personal finance app, mobile-only. No HTTP server, no login, no network
sync — everything runs in-process on the phone.

```
Flutter UI (mobile_app/) → Kotlin MethodChannels (moneef/api, moneef/backups)
  → mobilebridge/ (gomobile .aar, JSON bytes in/out, int64 IDs)
  → internal/<feature>/{dto,service,repository}
  → SQLite via GORM
```

Full bridge API: `mobilebridge/API.md`.

**Feature layer pattern:**
```
mobilebridge/<feature>.go → dto/ → service/ → repository/
```

**Startup sequence:** `mobilebridge.Init(dbPath, profileID)` → `db.Connect()` → `db.MigrateModels()` → seed icons/categories/currencies → ready. See `mobilebridge/init.go`.

Go starts on Android with `time.Local = UTC`; Kotlin calls `SetTimeZone(TimeZone.getDefault().id)` before `Init`. Dates are stored as UTC.

## Build tags

- `mobilebridge/` is gated `//go:build android || smoke` — invisible to plain `go build ./...` / `go test ./...`.
- `smoke` builds the binding on the host: `mobilebridge/_smoke/` (smoke driver) and `mobilebridge/_e2e/` (c-shared lib the Flutter e2e tests load over `dart:ffi`). `_`-prefixed dirs are skipped by `./...`.
- `internal/background.Run`: goroutine by default, synchronous on `android || smoke` (so derived writes can't race a backup/restore).

## Database

- SQLite via GORM with `github.com/glebarez/sqlite` (pure Go, no cgo, FTS5 built in); connection string: plain `<db_path>`. Foreign keys are deliberately **not** enforced (deleting a category keeps its splits; a cascade would wipe their amounts), so rules like "can't delete an account with activity" live in code
- Global handle: `db.DB *gorm.DB` — set once in `db.Connect()`, used directly by all repos
- Migrations: `db.MigrateModels()` runs `AutoMigrate` on every startup — no versioning tool
- Also creates FTS5 virtual table `icon_lookups_fts` with triggers for merchant icon search
- Money fields: always `types.Money` (shopspring/decimal), never `float64`
- Categories are soft-deleted; preload with `models.WithDeleted` where deleted categories still need to show (e.g. on old transactions)
- DB path: passed in by the caller. `mobilebridge.Init(dbPath, profileID)` sets it; there is no server/CLI path that defaults it anymore

## Config

`internal/config/config.go` — singleton via `sync.Once`. Holds only `DBPath`, set through `mobilebridge.Init`. The exchange-rate API key is not process config: it's a per-user setting (the user's own free exchangerate-api.com key, entered in Settings and stored in the DB — see `internal/users`); rates can also be set manually.

## Testing

No `/tests/` directory — this is a mobile app, not a server. Tests live next to the code they cover:

- Pure Go helpers have co-located unit tests (e.g. `internal/analysis/utils`, `internal/iconlookup`) — run with plain `go test ./...`
- Bridge tests sit in `mobilebridge/*_test.go`, need `go test -tags smoke ./mobilebridge/`
- Flutter unit/widget tests: `flutter test --exclude-tags screenshots`
- Flutter e2e tests drive the real Go core over `dart:ffi`, loading `build/libmoneef_e2e.so` — build it first (see Commands)
- Screenshot goldens are tagged `screenshots` and excluded from the default `flutter test` run

## Key Packages

| Path | Role |
|---|---|
| `internal/models/` | All GORM models (Profile, Transaction, Account, Pattern, Currency, etc.) |
| `internal/db/` | DB connection + migration |
| `internal/config/` | Config singleton, currency/country constants, merchant data |
| `internal/accounts/` | Accounts, transfers, set-balance, currency exchange |
| `internal/currencies/` | Currency list + exchange rate fetch/upsert |
| `internal/iconlookup/` | In-memory cache + FTS5 for merchant icon/color lookups |
| `internal/analysis/` | Spending charts, daily spend, period comparison |
| `internal/patterns/` | Spending pattern detection engine |
| `internal/background/` | `Run(task)` — async by default, sync on mobile (build-tag split) |
| `pkg/types/` | `Money` type alias for `shopspring/decimal.Decimal` |
| `pkg/utils/` | Currency conversion, HTTP retry helper for the exchange-rate API, string helpers |
| `mobilebridge/` | gomobile binding exposing the Go core to Flutter; JSON bytes in/out, `int64` IDs |
| `mobile_app/` | Flutter mobile client (Riverpod + go_router + freezed) over the native bridge |

## Design Context

`mobile_app/` is the Flutter mobile client. Visual tokens live in
`mobile_app/lib/theme.dart` (`AppColors`, `AppRadii`, `AppMotion`); that file is
the only design source of truth. Brand: calm, trustworthy, precise; violet
`#6C5CE7` mark, Manrope type.

The repo deliberately has no other agent-facing files (no DESIGN.md, PRODUCT.md,
generators, or design mockups). Don't add any.

Use the `/impeccable` skill for any mobile UI design work.
