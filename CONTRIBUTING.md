# Contributing to Moneef

## Development Setup

```bash
git clone <repo>
cd moneef-backend
cp .example.env .env
go mod download
go build -tags sqlite_fts5 ./...   # verify build
```

For the desktop app, also install [Wails CLI](https://wails.io/docs/gettingstarted/installation) and Node.js 20+:

```bash
cd desktop/frontend && npm install
cd desktop && wails dev
```

## Code Style

Feature layer order — always top-down, never skip layers:

```
handler.go  →  dto/  →  service/  →  repository/
```

- Handlers decode requests, validate, call service, write response.
- Services contain business logic. They call repositories, never touch `http`.
- Repositories contain GORM queries. They accept `*gorm.DB` as first parameter.
- Models live in `internal/models/`. No business logic on models.
- Money values use `types.Money` (shopspring/decimal). Never `float64`.

## Commit Conventions

[Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add X
fix: correct Y
refactor: reorganize Z
test: add tests for W
chore: update dependencies
docs: update README
```

Breaking changes: add `!` after type, e.g. `feat!: change API response shape`.

## Testing

All tests live in `/tests/` (not co-located with packages). Tests use a real in-memory SQLite database — no mocking.

```bash
go test -tags sqlite_fts5 ./tests/...                              # all integration tests
go test -tags sqlite_fts5 ./tests/ -run TestSuiteName/TestName    # single test
go test -tags sqlite_fts5 -race ./tests/...                       # with race detector
```

Every new feature or bug fix should have a corresponding test.

## Pull Request Process

1. Fork and create a branch from `master`.
2. Make sure `go build -tags sqlite_fts5 ./...` passes.
3. Make sure `go test -tags sqlite_fts5 -race ./tests/...` passes.
4. Run `go vet ./...` and fix any issues.
5. Open a PR against `master` with a clear description of what changed and why.

## License

By contributing you agree your contributions are licensed under the MIT License.
