# Contributing to Moneef

## Development Setup

```bash
git clone <repo>
cd moneef-backend
cp .example.env .env
go mod download
go build ./...   # verify build
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

Integration tests live in `/tests/` and use a real in-memory SQLite database — no mocking. Pure helpers may have co-located unit tests, and the mobile binding tests sit in `mobile/*_test.go` (run with `go test -tags smoke ./mobile/`).

```bash
go test ./tests/...                              # all integration tests
go test ./tests/ -run TestSuiteName/TestName    # single test
go test -race ./tests/...                       # with race detector
```

Every new feature or bug fix should have a corresponding test.

## Pull Request Process

1. Fork and create a branch from `master`.
2. Make sure `go build ./...` passes.
3. Make sure `go test -race ./tests/...` passes.
4. Run `go vet ./...` and fix any issues.
5. Open a PR against `master` with a clear description of what changed and why.

## License

By contributing you agree your contributions are licensed under the MIT License.
