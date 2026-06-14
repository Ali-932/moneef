# Plan — gomobile bind for Flutter (Android v1)

**Branch:** current
**Goal:** Produce `mobile/moneef.aar` consumable by a Flutter app via Kotlin MethodChannel. Backend Go code reused as-is via in-process JSON-in / JSON-out shims. Desktop + tests continue to work unchanged.

User decisions captured:
- Bridge: Platform Channels (Kotlin MethodChannel → `.aar`).
- Target: Android only for v1. iOS deferred.
- SQLite driver: swap **repo-wide** from `gorm.io/driver/sqlite` (cgo/mattn) to `github.com/glebarez/sqlite` (pure-Go modernc, FTS5 bundled). Desktop and tests use the same driver.

Out of scope for this PR:
- iOS `.xcframework`.
- Flutter app itself (we ship the `.aar` + a Kotlin MethodChannel snippet for integration; the Flutter project lives elsewhere).
- Replacing the HTTP/REST architecture for desktop; cmd/api and desktop continue to use the same services via HTTP.

---

## Architecture decisions

### A1 — `mobile/` API surface (gomobile-bindable)

`mobile/api.go` exports a flat function set. **Hard rule:** every exported func uses only `string`, `[]byte`, `int64`, `error`, `bool`. No interfaces, no Go-only types, no channels, no `uint`. (gomobile bind cannot marshal `uint` — must use `int64` and convert internally.)

Functions exposed in v1:

| Function | Signature | Purpose |
|---|---|---|
| `Init` | `(dbPath string, profileID int64) error` | Open DB at `dbPath`, run `MigrateModels`, `LoadCache`, store profileID in a `sync.RWMutex`-guarded package var |
| `Shutdown` | `() error` | Close GORM `sql.DB` connection cleanly, clear globals |
| `Setup` | `(payload []byte) ([]byte, error)` | First-run user+profile+settings creation. Returns `{profile_id, user_id, currency_code, ...}` so Flutter can store profile_id locally and pass back to `Init` next launch |
| `CreateTransaction` | `(payload []byte) ([]byte, error)` | JSON `TransactionRequest` → calls `transactions/service.HandleTransactionCreation` → returns `{"message":"created"}` |
| `ListTransactions` | `(payload []byte) ([]byte, error)` | JSON `{type, category_id, date_from, date_to, search, category_name, sort, page, per_page}` → inline pagination (Count+Offset+Limit on `*gorm.DB` returned by service) → returns `{count, total_pages, current_page, per_page, results: []Transaction}` |
| `GetTransaction` | `(id int64) ([]byte, error)` | |
| `UpdateTransaction` | `(id int64, payload []byte) ([]byte, error)` | |
| `DeleteTransaction` | `(id int64) error` | |
| `ListCategories` | `(payload []byte) ([]byte, error)` | JSON `{type, custom, used}` → `[]Category` |
| `CreateCategory` | `(payload []byte) ([]byte, error)` | Returns refreshed `Category` |
| `UpdateCategory` | `(id int64, payload []byte) error` | |
| `DeleteCategory` | `(id int64) error` | |
| `Dashboard` | `(payload []byte) ([]byte, error)` | JSON `{date_from, date_to}` (RFC3339, both optional) → `DashboardResponse` |
| `Analysis` | `(payload []byte) ([]byte, error)` | JSON `{start_date, end_date, currency}` → `AnalysisCharts` |
| `Patterns` | `() ([]byte, error)` | Calls `repository.GetPatternsByProfileID(db.DB, profileID)` for fast read |
| `RefreshPatterns` | `(payload []byte) ([]byte, error)` | JSON `{start_date?, end_date?}` → `pattern_engine.GetUserPatterns` |
| `GetProfile` | `() ([]byte, error)` | Calls `users/service.GetProfile` + `GetUserByID`, merges into `ProfileResponse` |
| `UpdateProfile` | `(payload []byte) error` | |
| `GetSettings` | `() ([]byte, error)` | Resolves `userID` from `GetProfile(profileID).UserID`, then `GetSettings(userID)` |
| `UpdateSettings` | `(payload []byte) error` | Same userID resolution |

**Profile ID handling:** stored in a package-level `int64` guarded by `sync.RWMutex`. `Init` sets it; every exported func reads via `getProfileID()`. If unset (≤ 0), funcs return `ErrNotInitialized`. **`SetProfileID(int64) error`** is also exported to let Flutter switch profiles without re-running `Init`.

**Errors:** wrapped to a JSON envelope on the Kotlin/Dart side? **No.** We return native Go `error` — gomobile wraps it as `java.lang.Exception` automatically. Flutter catches via `PlatformException`. This keeps the Go side clean. Errors are unstructured strings; Flutter shows them or logs them.

**Money serialization:** `types.Money` (shopspring decimal) marshals to JSON as a **string** (`"10.50"`). The Flutter side must use `Decimal.parse(json['amount'])` from `decimal.dart`. Documented in `mobile/README.md`.

### A2 — Build tags

| Files | Tag | Reason |
|---|---|---|
| All files in `mobile/*.go` | `//go:build android` | Only compiled when binding for Android. Standalone `go build ./...` skips them. |
| `cmd/api/main.go` | `//go:build !android` | Server uses `os/signal.Notify(SIGINT, SIGTERM)` + listens on TCP — not viable inside an Android app process. |
| `cmd/run.go` | `//go:build !android` | Uses `os/exec` to invoke `go run`. Banned on Android. |
| `cmd/cron/currency_rate_cron.go` | `//go:build !android` | Cron entry, irrelevant on mobile. Already broken (`func main() error`); leave as-is, just gate it. |
| `desktop/main.go`, `desktop/app.go` | `//go:build !android` | Wails pulls cgo libs not available on the Android NDK toolchain (`go-webview2`, `wailsapp/wails/v2/pkg/runtime`). |
| `internal/config/config_log_default.go` (new, holds existing `SetUpLogs`) | `//go:build !android` | `app.log` at CWD doesn't exist on Android sandbox. |
| `internal/config/config_log_android.go` (new) | `//go:build android` | Writes to `os.UserConfigDir()+"/moneef/app.log"`. |

The user's spec said `-tags mobile`. **Deviation:** I use `//go:build android` instead, because gomobile sets `GOOS=android` automatically. Manual `-tags mobile` plumbing would require us to also pass `-tags` to gomobile (it does support this), but `android` is the natural and conventional gate. **Build verification command updated accordingly:**

```bash
go build ./cmd/api/...                       # !android — desktop server
go build ./desktop/...                       # !android — Wails
GOOS=android CGO_ENABLED=0 go build ./mobile # android-only graph
gomobile bind -target=android -androidapi 21 -o build/moneef.aar ./mobile
```

If the user strictly wants `-tags mobile`, change every `//go:build android` above to `//go:build android || mobile` and run `gomobile bind -target=android -tags mobile`. We will use `android` alone unless instructed otherwise.

### A3 — SQLite driver swap

- Remove `gorm.io/driver/sqlite v1.6.0` from `go.mod`.
- Add `github.com/glebarez/sqlite` (latest stable, currently v1.11.0).
- Replace import in `internal/db/db.go:10`, `tests/test_utils.go:19`.
- Connection string stays the same: `<path>?_foreign_keys=on&_journal_mode=WAL`. modernc parses these the same way.
- FTS5: modernc bundles libsqlite3 with FTS5 enabled by default. `migrate_models.go` graceful fallback stays in place as a safety net.
- Side effect: `mattn/go-sqlite3` drops from `go.sum`. `CGO_ENABLED=0` builds become possible for everything.
- All tests rerun to confirm parity.

### A4 — Reused service code

Zero changes required to:
- `internal/transactions/service/*`
- `internal/categories/service/*`
- `internal/dashboard/service/*`
- `internal/analysis/service/*`
- `internal/users/service/*`
- `internal/patterns/pattern_engine/*`
- `internal/patterns/repository/*`
- `internal/iconlookup/*`
- All models, all DTOs

This is the critical win — the service layer is already context-agnostic for identity (every function takes `profileID uint` explicitly), so no refactor is needed.

### A5 — Pagination

`pkg/pagination.Paginate` needs `*http.Request`. We **cannot** use it in `mobile/`. Instead, `ListTransactions` shim:

```go
query := txnService.ListTransactions(profileID, ...)
var count int64
query.Session(&gorm.Session{}).Count(&count)
var results []models.Transaction
offset := (page - 1) * perPage
if err := query.Offset(offset).Limit(perPage).Find(&results).Error; err != nil { ... }
// Build minimal PaginatedResult (Next/Previous left empty — Flutter uses page+per_page directly)
```

Returns:
```json
{
  "count": 123,
  "total_pages": 7,
  "current_page": 1,
  "per_page": 20,
  "results": [...]
}
```

No `next` / `previous` URLs (irrelevant for in-process calls).

---

## Task list (atomic steps)

### Phase 1 — SQLite driver swap + dep changes

1. **`go.mod`**: replace `gorm.io/driver/sqlite v1.6.0` with `github.com/glebarez/sqlite v1.11.0`. Run `go mod tidy`. Confirm `mattn/go-sqlite3` drops from `go.sum`.
2. **`internal/db/db.go:10`**: change import to `"github.com/glebarez/sqlite"`. No other changes.
3. **`tests/test_utils.go:19`**: same swap.
4. **Verify**: `go build ./...` exits 0; `go test ./tests/...` passes (no `-tags sqlite_fts5` needed — the tag was a no-op anyway).

### Phase 2 — Android-friendly config

5. **Split `internal/config/config.go`**: move `SetUpLogs` into `config_log_default.go` (with `//go:build !android`) and add `config_log_android.go` (with `//go:build android`) that opens `os.UserConfigDir()+"/moneef/app.log"` (creating dir as needed).
6. **Verify**: `go build ./...` still passes; `GOOS=android CGO_ENABLED=0 go build ./internal/config/...` passes.

### Phase 3 — Gate desktop/cmd files for android

7. Add `//go:build !android` to top of:
   - `cmd/api/main.go`
   - `cmd/run.go`
   - `cmd/cron/currency_rate_cron.go`
   - `desktop/app.go`
   - `desktop/main.go`
8. **Verify**: `go build ./...` passes; `GOOS=android CGO_ENABLED=0 go build ./internal/... ./pkg/...` passes (this confirms no android-hostile imports remain in the reachable graph).

### Phase 4 — Create `mobile/` package

9. **`mobile/state.go`** (`//go:build android`): package-level `profileID int64` + `sync.RWMutex` + `dbHandle *gorm.DB` + `initialized bool`. Helpers: `getProfileID()`, `setProfileID(int64) error`, `requireInit() error`.
10. **`mobile/errors.go`** (`//go:build android`): sentinel errors — `ErrNotInitialized`, `ErrInvalidPayload`, `ErrProfileNotSet`. Helper `mobileErr(format, args)` to standardize wrapping.
11. **`mobile/init.go`** (`//go:build android`): `Init(dbPath string, profileID int64) error` — sets `config.GetConfig()` (already singleton; we monkey-patch by reading env directly? no — see decision below) → `db.Connect()` requires `config.GetConfig().DBPath`. **Sub-decision:** in `mobile/init.go`, we set `os.Setenv("db_path", dbPath)` BEFORE calling `config.GetConfig()`. The existing config singleton then picks it up. Simpler than refactoring config. Also calls `db.MigrateModels` + `iconlookup.LoadCache`. `Shutdown()` closes `*sql.DB` and resets `initialized = false`.
12. **`mobile/setup.go`**: `Setup(payload []byte) ([]byte, error)` wraps `users/service.Setup`.
13. **`mobile/transactions.go`**: `CreateTransaction`, `ListTransactions`, `GetTransaction`, `UpdateTransaction`, `DeleteTransaction`. Each:
    - `requireInit()`
    - JSON unmarshal into handler DTO
    - call validator (re-using `Validate()` methods where present)
    - call service with `getProfileID()` cast to `uint`
    - JSON marshal result
14. **`mobile/categories.go`**: `ListCategories`, `CreateCategory`, `UpdateCategory`, `DeleteCategory`.
15. **`mobile/dashboard.go`**: `Dashboard(payload []byte) ([]byte, error)`.
16. **`mobile/analysis.go`**: `Analysis(payload []byte) ([]byte, error)`. Resolves currency from settings if not in payload (uses `users/service.GetSettings(userID)` lookup chain).
17. **`mobile/patterns.go`**: `Patterns()` + `RefreshPatterns(payload []byte)`.
18. **`mobile/profile.go`**: `GetProfile`, `UpdateProfile`, `GetSettings`, `UpdateSettings`. Resolves `userID` from `profile.UserID` for settings calls.
19. **`mobile/doc.go`**: package doc comment + build-tag explanation.
20. **`mobile/README.md`**: build instructions for `gomobile bind`, Kotlin MethodChannel example wiring, sample Dart call patterns, money/decimal note, error/PlatformException note. **Does not need to be exhaustive Flutter docs** — just enough that a Flutter dev can ship a smoke test.

### Phase 5 — Build verification

21. **Native Go build (no android tag):** `go build ./...` → exit 0.
22. **Android cross-compile (no gomobile):** `GOOS=android CGO_ENABLED=0 GOARCH=arm64 go build ./mobile/... ./internal/... ./pkg/...` → exit 0. **This is the fastest signal that the import graph is clean before invoking gomobile.**
23. **Tests:** `go test ./tests/...` → all pass. **Critical gate:** if the sqlite swap broke any test, it must be fixed here, not later.
24. **gomobile bind:** `gomobile bind -target=android -androidapi 21 -o build/moneef.aar ./mobile`. Requires `gomobile init` once on the dev machine. Produces `build/moneef.aar` + `build/moneef-sources.jar`. **If gomobile isn't installed locally, document the install command in `mobile/README.md` and skip the live bind step — the cross-compile in step 22 is sufficient signal that the source is correct.**

### Phase 6 — Smoke test guidance

25. **`mobile/README.md`** includes:
    - Kotlin MethodChannel snippet that calls `Init`, `Setup`, `CreateTransaction`, `ListTransactions`
    - Dart side `MethodChannel('moneef')` invocation snippet
    - Expected JSON shapes
    - Notes on `Decimal` parsing and `PlatformException` handling

26. **Optional `mobile/_smoke/`** (NOT compiled by android tag — uses `//go:build smoke`): A pure-Go driver script that calls `mobile.Init(":memory:" or tmp path, 1)`, `mobile.Setup(...)`, `mobile.CreateTransaction(...)`, prints results. Runnable via `go run -tags=smoke ./mobile/_smoke/` to validate the JSON contract without needing an Android device. **This is the closest substitute for "manual smoke test in a Phase 0 spike app".**

---

## Done criteria

- [ ] `go build ./...` exits 0 (native, default tags)
- [ ] `GOOS=android CGO_ENABLED=0 go build ./mobile/... ./internal/... ./pkg/...` exits 0
- [ ] `go test ./tests/...` passes — every existing test (no regression from sqlite swap)
- [ ] `mobile/` exists with all functions above, each with `//go:build android` tag
- [ ] `mobile/README.md` exists with Kotlin/Dart wiring snippets
- [ ] `mobile/_smoke/main.go` exists and runs end-to-end against a tmp sqlite file: Init → Setup → CreateTransaction → ListTransactions returns the inserted transaction
- [ ] Desktop hot-reload (`air`) still works on Linux (`!android` path)
- [ ] No use of `as any`, `@ts-ignore`, suppression — full type-safe Go

**Stretch (out of scope but noted):**
- `gomobile bind -target=android` succeeds locally if `gomobile` is installed.
- iOS xcframework target (deferred to a separate PR).

---

## Risk register

| Risk | Mitigation |
|---|---|
| glebarez/sqlite produces different SQL behavior than mattn (date parsing, NULL handling, edge cases) | Full test suite rerun at step 23 is the gate. If any test fails, investigate and fix or rollback. |
| FTS5 missing in modernc despite docs | Existing graceful fallback in `migrate_models.go` already logs a warning and continues. Icon lookup uses in-memory cache anyway, so no feature breakage. |
| `gomobile bind` not installed | Document install in README; cross-compile (step 22) is the actual correctness gate. |
| `config.GetConfig()` singleton race when `Init` is called after some other call already triggered `sync.Once` | `Init` is called first by Flutter side; race is real only if a test or another caller initializes config. Mitigation: `Init` calls `os.Setenv("db_path", dbPath)` BEFORE first `GetConfig()`. We add a comment + a panic-with-clear-message if `DBPath != dbPath` after the call. |
| `app.log` write fails on Android (read-only FS or permission) | New `config_log_android.go` writes to `os.UserConfigDir()` which is always writable; if it fails, we log to stderr only and continue (no panic). |
| Pagination Next/Previous URLs missing on mobile | Documented in `mobile/README.md`. Flutter side computes pagination state from `page`/`per_page` directly. |
| `Setup` runs `bcrypt` which is pure-Go but slow on android arm64 | Accepted. Setup happens once. |
| User changed their mind and wants `-tags mobile` instead of `//go:build android` | Trivial s/r at the end. Not blocking. |

---

## Verification commands (copy-pasteable)

```bash
# Phase 1 — driver swap verification
go mod tidy
go build ./...
go test ./tests/...

# Phase 3 — android-graph cleanliness (no gomobile required)
GOOS=android CGO_ENABLED=0 GOARCH=arm64 go build ./internal/... ./pkg/...

# Phase 4/5 — mobile package
GOOS=android CGO_ENABLED=0 GOARCH=arm64 go build ./mobile/...

# Phase 5 — gomobile (only if installed)
gomobile bind -target=android -androidapi 21 -o build/moneef.aar ./mobile

# Phase 6 — smoke
go run -tags=smoke ./mobile/_smoke/
```

---

## Open questions (none — all decisions captured above)

User decisions are locked. Proceeding to implementation in the order: Phase 1 → 2 → 3 → 4 → 5 → 6, with the test suite as the gate between each phase.
