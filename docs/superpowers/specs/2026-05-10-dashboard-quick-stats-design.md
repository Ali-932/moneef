# Dashboard Quick Stats Enhancement

## Date
2026-05-10

## Context
The Home dashboard's "Quick Stats" card currently shows only 2 rows (transaction count + top category) with ~80% empty space. All stats must be computed server-side; the frontend must only render.

## Design

### Backend Changes

Add a nested `QuickStats` struct to the existing `AnalysisCharts` DTO:

```go
type QuickStats struct {
    SavingsRate       types.Money `json:"savings_rate"`
    BiggestTransaction struct {
        Name   string      `json:"name"`
        Amount types.Money `json:"amount"`
        Icon   string      `json:"icon"`
        Color  string      `json:"color"`
    } `json:"biggest_transaction"`
    TransactionCount int `json:"transaction_count"`
    TopMerchant      struct {
        Name   string      `json:"name"`
        Amount types.Money `json:"amount"`
    } `json:"top_merchant"`
}
```

`AnalysisCharts` gains one new field:
```go
QuickStats QuickStats `json:"quick_stats"`
```

### New Repository Queries (parallel goroutines)

1. `GetTotalIncome` — mirrors `GetTransactionTotalExpense` but `type = 'income'`
2. `GetBiggestTransaction` — single transaction with max category amount in period
3. `GetTransactionCount` — `COUNT(DISTINCT transactions.id)` in period
4. `GetTopMerchant` — `GROUP BY merchant_name, SUM(tc.amount), ORDER DESC, LIMIT 1`

### Service Logic

In `GetAllAnalysisChartsService`, add 4 new `errgroup` goroutines. After `g.Wait()`:
- `savings_rate = (totalIncome - totalExpense) / totalIncome * 100`
- If `totalIncome == 0`, `savings_rate = 0`
- Populate `QuickStats` from the 4 new query results

### Frontend Changes

Update `Home.tsx` Quick Stats section to render 6 rows:
1. Transactions this period — count
2. Top category — name + amount (existing)
3. Savings rate — percentage
4. Biggest transaction — name + amount + icon + color
5. Top merchant — name + amount
6. Avg transaction — `total / count` (computed in service, or frontend can do simple division)

Wait — avg should also be backend. Add `AvgTransaction types.Money` to QuickStats.

Updated QuickStats:
```go
type QuickStats struct {
    SavingsRate       types.Money `json:"savings_rate"`
    BiggestTransaction struct {
        Name   string      `json:"name"`
        Amount types.Money `json:"amount"`
        Icon   string      `json:"icon"`
        Color  string      `json:"color"`
    } `json:"biggest_transaction"`
    TransactionCount int         `json:"transaction_count"`
    TopMerchant      struct {
        Name   string      `json:"name"`
        Amount types.Money `json:"amount"`
    } `json:"top_merchant"`
    AvgTransaction types.Money `json:"avg_transaction"`
}
```

## Files to Modify
- `internal/analysis/dto/service_dto.go` — add QuickStats struct
- `internal/analysis/repository/analysis_repository.go` — 4 new queries
- `internal/analysis/service/analysis_service.go` — wire goroutines + calculations
- `desktop/frontend/src/pages/Home.tsx` — render new stats

## Out of Scope
- Days remaining / period trend (can be added later)
- Caching (not needed yet)

## Spec Self-Review
- No TBDs or placeholders
- Consistent with existing errgroup + mutex pattern
- All calculations backend-side
- Frontend only renders
