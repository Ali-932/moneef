# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

**Backend**
```bash
go run ./cmd/api/          # start API server
go run . seed              # seed categories, currencies, users
go run . seed-transactions # seed realistic transaction data
go run . seed-merchants    # seed merchant icon lookups
go run . fetch-rates       # fetch exchange rates
go test ./...              # all tests
go test ./tests/...        # integration tests only
go test ./tests/ -run TestSuiteName/TestName  # single test
air                        # hot-reload (uses .air.toml)
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
tool/design_review.sh                     # analyze + tests + screenshot goldens
```

## Architecture

Personal finance app. Two runtime modes:
1. **Standalone HTTP server** — `cmd/api/main.go` on configured port
2. **Mobile binding** — `mobilebridge/` (gomobile `.aar`) calls the same services in-process; the Flutter app reaches it through Kotlin `MethodChannel`s (`moneef/api`, `moneef/backups`). No HTTP on mobile. Full API: `mobilebridge/API.md`.

**Startup sequence (HTTP server):**
```
db.Connect() → db.MigrateModels() → iconlookup.LoadCache() → routes.SetupRoutes() → ListenAndServe()
```

**Feature layer pattern:**
```
handler.go → dto/ → service/ → repository/
```

**Route groups:**
- Unprotected: `POST /api/v1/setup`, `GET /api/v1/currencies`, `GET /api/v1/healthz`
- Protected: everything else — requires `X-Profile-ID: <uint>` header

## Auth

No JWT. Header-based identity only. `pkg/middleware/ProfileMiddleware` reads `X-Profile-ID` header, queries DB for `Profile` (with `User` preloaded), injects `ContextKeyProfileID` and `ContextKeyUserID` into request context. Handlers read via `r.Context().Value(middleware.ContextKeyProfileID).(uint)`.

## Build tags

- `mobilebridge/` is gated `//go:build android || smoke` — invisible to plain `go build ./...` / `go test ./...`.
- `smoke` builds the binding on the host: `mobilebridge/_smoke/` (smoke driver) and `mobilebridge/_e2e/` (c-shared lib the Flutter e2e tests load over `dart:ffi`). `_`-prefixed dirs are skipped by `./...`.
- `internal/background.Run`: goroutine on server/CLI, synchronous on `android || smoke` (so derived writes can't race a backup/restore).
- `cmd/api/` and `cmd/run.go` are `//go:build !android`.

## Database

- SQLite via GORM with `github.com/glebarez/sqlite` (pure Go, no cgo, FTS5 built in); connection string: plain `<db_path>`. Foreign keys are deliberately **not** enforced (deleting a category keeps its splits; a cascade would wipe their amounts), so rules like "can't delete an account with activity" live in code
- Global handle: `db.DB *gorm.DB` — set once in `db.Connect()`, used directly by all repos
- Migrations: `db.MigrateModels()` runs `AutoMigrate` on every startup — no versioning tool
- Also creates FTS5 virtual table `icon_lookups_fts` with triggers for merchant icon search
- Money fields: always `types.Money` (shopspring/decimal), never `float64`
- DB path: `db_path` from env/`.env`; if empty, `os.UserConfigDir()/moneef/db.sqlite`. On mobile, `mobilebridge.Init(dbPath, ...)` passes it in.

## Config

`internal/config/config.go` — singleton via `sync.Once`. Loads `.env` via `godotenv`. Keys:
- `port` — default `:8000`
- `db_path` — defaults to the OS config dir (see Database)
- `exchange_rate_api_key` — for currency rates

## Testing

Integration tests live in `/tests/`: `httptest.Server` + real Chi router + real in-memory SQLite. No mocking. Exceptions: pure helpers may have co-located unit tests (e.g. `internal/analysis/utils`), and binding tests sit in `mobilebridge/*_test.go` (need `-tags smoke`).

- Test DB: `file:memdb_<timestamp>?mode=memory&cache=shared`, fresh per suite, full `AutoMigrate` run
- `db.DB` global is swapped for test DB, restored in `Cleanup()`
- Test requests include `X-Profile-ID: 1` directly (header auth)
- Seed helpers in `tests/test_utils.go`: `seedTestData()`, pointer helpers (`PtrBool`, `PtrString`, `MoneyFromFloat`, etc.)

## Key Packages

| Path | Role |
|---|---|
| `internal/models/` | All GORM models (User, Profile, Transaction, Pattern, Currency, etc.) |
| `internal/db/` | DB connection + migration |
| `internal/routes/` | Chi router setup |
| `internal/config/` | Config singleton, currency/country constants, merchant data |
| `internal/iconlookup/` | In-memory cache + FTS5 for merchant icon/color lookups |
| `internal/analysis/` | Spending charts, daily spend, period comparison |
| `internal/patterns/` | Spending pattern detection engine |
| `pkg/middleware/` | `ProfileMiddleware` (header-based auth injection), context keys |
| `pkg/pagination/` | Generic `Paginate[T]()` using GORM + query params |
| `pkg/types/` | `Money` type alias for `shopspring/decimal.Decimal` |
| `pkg/utils/` | `WriteJsonError`, password hashing, date/frequency helpers, currency utils |
| `internal/background/` | `Run(task)` — async on server, sync on mobile (build-tag split) |
| `cmd/` | Cobra dev CLI (root `main.go`): `seed`, `seed-transactions`, `seed-merchants`, `fetch-rates`, `run`; `cmd/api/` is the server |
| `mobilebridge/` | gomobile binding exposing the Go core to Flutter; JSON bytes in/out, `int64` IDs |
| `mobile_app/` | Flutter mobile client (Riverpod + go_router + freezed) over the native bridge |

## Design Context

`mobile_app/` is the Flutter mobile client. Its design system is documented in:
- `mobile_app/PRODUCT.md` — register: **product**; users, purpose, brand
  personality (calm/trustworthy/precise), anti-references, design principles.
- `mobile_app/DESIGN.md` — visual system (colors, typography, components) when present.
- Visual tokens live in `mobile_app/lib/theme.dart` (`AppColors`, `AppRadii`,
  `AppMotion`).

Use the `/impeccable` skill for any mobile UI design work so it loads this context.
