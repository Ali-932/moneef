# Moneef

Personal finance tracker. Single-user desktop app with a Go backend, React frontend, and SQLite database.

## Architecture

Two runtime modes share the same router:

- **Standalone server** — `cmd/api/main.go`, listens on configured port
- **Desktop app** — `desktop/app.go` (Wails v2), embeds the server at `127.0.0.1:7331`

```
Request → Chi Router → ProfileMiddleware → Handler → Service → Repository → SQLite (GORM)
```

Auth is header-based: all protected routes require `X-Profile-ID: <uint>`. No JWT, no sessions.

## Tech Stack

| Layer | Tech |
|---|---|
| Language | Go 1.24 |
| Router | Chi v5 |
| ORM | GORM + SQLite (FTS5) |
| Desktop shell | Wails v2 |
| Frontend | React 18 + TypeScript + Vite + Tailwind v4 + DaisyUI v5 |
| Money | shopspring/decimal |

## Prerequisites

- Go 1.24+
- Node.js 20+
- [Wails CLI](https://wails.io/docs/gettingstarted/installation): `go install github.com/wailsapp/wails/v2/cmd/wails@latest`

## Quickstart

```bash
git clone <repo>
cd moneef-backend
cp .example.env .env
go run ./cmd/api/          # standalone server on :8000
```

First request: `POST /api/v1/setup` to create user + profile.

## Development Commands

```bash
# Backend
go run ./cmd/api/          # start server
air                        # hot-reload (requires air: go install github.com/air-verse/air@latest)
go test -tags sqlite_fts5 ./tests/...   # integration tests
go build -tags sqlite_fts5 ./...        # build check

# Desktop
cd desktop && wails dev    # hot-reload Wails + React
cd desktop && wails build  # production binary

# Frontend only
cd desktop/frontend && npm run dev
cd desktop/frontend && npm run build
```

## API Endpoints

### Public

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/v1/setup` | Create user + profile (first-run) |
| `GET` | `/api/v1/currencies` | List supported currencies |
| `GET` | `/api/v1/healthz` | Health check |

### Protected (requires `X-Profile-ID` header)

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/v1/transaction/` | List transactions (search, filter, paginate) |
| `POST` | `/api/v1/transaction/create` | Create transaction |
| `GET` | `/api/v1/transaction/{id}` | Get transaction |
| `PUT` | `/api/v1/transaction/{id}` | Update transaction |
| `DELETE` | `/api/v1/transaction/{id}` | Delete transaction |
| `GET` | `/api/v1/category/` | List categories |
| `POST` | `/api/v1/category/` | Create category |
| `PUT` | `/api/v1/category/{id}` | Update category |
| `DELETE` | `/api/v1/category/{id}` | Delete category |
| `GET` | `/api/v1/dashboard/` | Dashboard summary |
| `GET` | `/api/v1/recurrence/` | List recurrence templates |
| `GET` | `/api/v1/recurrence/timeline` | Recurrence timeline |
| `PUT` | `/api/v1/recurrence/{id}` | Update recurrence |
| `DELETE` | `/api/v1/recurrence/{id}` | Delete recurrence |
| `POST` | `/api/v1/analysis/get_spending_by_category` | Spending analysis charts |
| `GET` | `/api/v1/analysis/patterns` | Spending patterns |
| `POST` | `/api/v1/analysis/patterns/refresh` | Refresh patterns |
| `GET` | `/api/v1/user/profile` | Get profile |
| `PUT` | `/api/v1/user/profile` | Update profile |
| `GET` | `/api/v1/user/settings` | Get settings |
| `PUT` | `/api/v1/user/settings` | Update settings |

## Project Structure

```
.
├── cmd/
│   └── api/            # standalone server entrypoint
├── desktop/            # Wails desktop shell
│   └── frontend/       # React + TypeScript app
├── internal/
│   ├── analysis/       # spending charts and pattern detection
│   ├── categories/
│   ├── config/         # singleton config, constants, merchant data
│   ├── currencies/
│   ├── dashboard/
│   ├── db/             # connection + AutoMigrate
│   ├── iconlookup/     # FTS5 merchant icon cache
│   ├── models/         # GORM models
│   ├── patterns/       # pattern detection engine
│   ├── routes/         # Chi router setup
│   ├── transactions/
│   └── users/
├── pkg/
│   ├── middleware/     # ProfileMiddleware, context keys
│   ├── pagination/     # generic GORM paginator
│   ├── types/          # Money type (decimal alias)
│   └── utils/          # JSON helpers, password, date/frequency, currency
└── tests/              # integration tests (httptest + real SQLite)
```

## License

MIT — see [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
