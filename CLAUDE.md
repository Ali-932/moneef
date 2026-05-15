# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

**Backend**
```bash
go run ./cmd/api/          # start API server
go run . seed              # seed categories, currencies, users
go run . seed-transactions # seed realistic transaction data
go test ./...              # all tests
go test ./tests/...        # integration tests only
go test ./tests/ -run TestSuiteName/TestName  # single test
air                        # hot-reload (uses .air.toml)
```

**Desktop**
```bash
cd desktop && wails dev    # hot-reload Wails + React
cd desktop && wails build  # production binary
```

**Frontend**
```bash
cd desktop/frontend && npm run dev    # Vite dev server
cd desktop/frontend && npm run build  # tsc + vite build
```

## Architecture

Personal finance app. Two runtime modes:
1. **Standalone HTTP server** — `cmd/api/main.go` on configured port
2. **Embedded in Wails desktop** — `desktop/app.go` starts same router on fixed `127.0.0.1:7331`

**Startup sequence (both modes):**
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

## Database

- SQLite via GORM, connection string: `<db_path>?_foreign_keys=on&_journal_mode=WAL`
- Global handle: `db.DB *gorm.DB` — set once in `db.Connect()`, used directly by all repos
- Migrations: `db.MigrateModels()` runs `AutoMigrate` on every startup — no versioning tool
- Also creates FTS5 virtual table `icon_lookups_fts` with triggers for merchant icon search
- Money fields: always `types.Money` (shopspring/decimal), never `float64`
- Default DB path: `db.sqlite` in project root (dev); `os.UserConfigDir()/moneef/db.sqlite` (prod)

## Config

`internal/config/config.go` — singleton via `sync.Once`. Loads `.env` via `godotenv`. Keys:
- `port` — default `:8000`
- `db_path` — default dev path
- `exchange_rate_api_key` — for currency rates

## Testing

All tests in `/tests/` (not co-located). Use `httptest.Server` + real Chi router + real in-memory SQLite. No mocking.

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
| `desktop/` | Wails v2 shell; `app.go` embeds HTTP server |
| `desktop/frontend/` | React 18 + TypeScript + Vite + Tailwind v4 + DaisyUI v5 + Recharts |
