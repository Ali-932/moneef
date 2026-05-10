# Dashboard Quick Stats Enhancement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add computed quick stats (savings rate, biggest transaction, transaction count, top merchant, avg transaction) to the dashboard API response and render them in the frontend Quick Stats card.

**Architecture:** Extend the existing `AnalysisCharts` DTO with a nested `QuickStats` struct. Add 4 new parallel DB queries in the analysis repository, wire them via errgroup in the service, compute derived fields after `g.Wait()`. Frontend receives the new fields and renders 6 stat rows.

**Tech Stack:** Go 1.24, GORM, Chi, React + TypeScript, TailwindCSS

---

## Files to Create/Modify

| File | Action | Responsibility |
|------|--------|----------------|
| `internal/analysis/dto/service_dto.go` | Modify | Add `QuickStats` struct and field to `AnalysisCharts` |
| `internal/analysis/repository/analysis_repository.go` | Modify | Add 4 new query functions |
| `internal/analysis/service/analysis_service.go` | Modify | Wire new queries into errgroup, compute derived fields |
| `desktop/frontend/src/pages/Home.tsx` | Modify | Render 6 quick stat rows from new API fields |

---

### Task 1: Add QuickStats DTO

**Files:**
- Modify: `internal/analysis/dto/service_dto.go`

- [ ] **Step 1: Add QuickStats struct and BiggestTransaction/TopMerchant structs**

Add these types above `AnalysisCharts`:

```go
type BiggestTransaction struct {
	Name   string      `json:"name"`
	Amount types.Money `json:"amount"`
	Icon   string      `json:"icon"`
	Color  string      `json:"color"`
}

type TopMerchant struct {
	Name   string      `json:"name"`
	Amount types.Money `json:"amount"`
}

type QuickStats struct {
	SavingsRate        types.Money        `json:"savings_rate"`
	BiggestTransaction BiggestTransaction `json:"biggest_transaction"`
	TransactionCount   int                `json:"transaction_count"`
	TopMerchant        TopMerchant        `json:"top_merchant"`
	AvgTransaction     types.Money        `json:"avg_transaction"`
}
```

Then add field to `AnalysisCharts`:
```go
type AnalysisCharts struct {
	Categories                []CategorySummary           `json:"categories"`
	CategoriesLastPeriod      []CategorySummary           `json:"categories_last_period"`
	SpentPerDay               []AmountPerDay              `json:"spent_per_day"`
	SpentPerDayLastPeriod     []AmountPerDay              `json:"spent_per_day_last_period"`
	NextRecurringTransactions []NextRecurringTransactions `json:"next_recurring_transactions"`
	Total                     types.Money                 `json:"total"`
	QuickStats                QuickStats                  `json:"quick_stats"`
}
```

- [ ] **Step 2: Verify compilation**

Run: `go build ./internal/analysis/...`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add internal/analysis/dto/service_dto.go
git commit -m "feat(analysis): add QuickStats DTO structs"
```

---

### Task 2: Add Repository Queries

**Files:**
- Modify: `internal/analysis/repository/analysis_repository.go`

- [ ] **Step 1: Add GetTotalIncome**

Append to `analysis_repository.go`:

```go
func GetTotalIncome(tx *gorm.DB, profileId uint, startDate, endDate time.Time, baseCurrency string) (types.Money, error) {
	var totalIncome types.Money
	err := tx.Model(&models.Transaction{}).
		Select("COALESCE(SUM(tc.amount * COALESCE(cer.rate, 1)),0) as total_income").
		Joins("JOIN transaction_categories tc ON transactions.id = tc.transaction_id").
		Joins("LEFT JOIN currency_exchange_rates cer ON transactions.currency_code = cer.currency_code1 AND cer.currency_code2 = (Select code FROM currencies WHERE code = ?)", baseCurrency).
		Where("transactions.profile_id = ? AND transactions.date >= ? AND transactions.date <= ? AND transactions.type = 'income' AND tc.deleted_at IS NULL", profileId, startDate, endDate).
		Scan(&totalIncome).Error
	if err != nil {
		return types.MoneyZero(), err
	}
	return totalIncome, nil
}
```

- [ ] **Step 2: Add GetTransactionCount**

```go
func GetTransactionCount(tx *gorm.DB, profileId uint, startDate, endDate time.Time) (int, error) {
	var count int64
	err := tx.Model(&models.Transaction{}).
		Where("profile_id = ? AND date >= ? AND date <= ? AND type = 'expense'", profileId, startDate, endDate).
		Count(&count).Error
	if err != nil {
		return 0, err
	}
	return int(count), nil
}
```

- [ ] **Step 3: Add GetBiggestTransaction**

```go
func GetBiggestTransaction(tx *gorm.DB, profileId uint, startDate, endDate time.Time, baseCurrency string) (dto.BiggestTransaction, error) {
	var result dto.BiggestTransaction
	err := tx.Model(&models.Transaction{}).
		Select("transactions.name as name, (tc.amount * COALESCE(cer.rate, 1)) as amount, c.icon as icon, c.color as color").
		Joins("JOIN transaction_categories tc ON transactions.id = tc.transaction_id").
		Joins("JOIN categories c ON tc.category_id = c.id").
		Joins("LEFT JOIN currency_exchange_rates cer ON transactions.currency_code = cer.currency_code1 AND cer.currency_code2 = (Select code FROM currencies WHERE code = ?)", baseCurrency).
		Where("transactions.profile_id = ? AND transactions.date >= ? AND transactions.date <= ? AND transactions.type = 'expense' AND tc.deleted_at IS NULL", profileId, startDate, endDate).
		Order("amount DESC").
		Limit(1).
		Scan(&result).Error
	if err != nil {
		return dto.BiggestTransaction{}, err
	}
	return result, nil
}
```

- [ ] **Step 4: Add GetTopMerchant**

```go
func GetTopMerchant(tx *gorm.DB, profileId uint, startDate, endDate time.Time, baseCurrency string) (dto.TopMerchant, error) {
	var result dto.TopMerchant
	err := tx.Model(&models.Transaction{}).
		Select("transactions.merchant_name as name, COALESCE(SUM(tc.amount * COALESCE(cer.rate, 1)),0) as amount").
		Joins("JOIN transaction_categories tc ON transactions.id = tc.transaction_id").
		Joins("LEFT JOIN currency_exchange_rates cer ON transactions.currency_code = cer.currency_code1 AND cer.currency_code2 = (Select code FROM currencies WHERE code = ?)", baseCurrency).
		Where("transactions.profile_id = ? AND transactions.date >= ? AND transactions.date <= ? AND transactions.type = 'expense' AND tc.deleted_at IS NULL AND transactions.merchant_name != ''", profileId, startDate, endDate).
		Group("transactions.merchant_name").
		Order("amount DESC").
		Limit(1).
		Scan(&result).Error
	if err != nil {
		return dto.TopMerchant{}, err
	}
	return result, nil
}
```

- [ ] **Step 5: Verify compilation**

Run: `go build ./internal/analysis/...`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add internal/analysis/repository/analysis_repository.go
git commit -m "feat(analysis): add quick stats repository queries"
```

---

### Task 3: Wire QuickStats into Service

**Files:**
- Modify: `internal/analysis/service/analysis_service.go`

- [ ] **Step 1: Add new result variables and goroutines**

In `GetAllAnalysisChartsService`, add these variables after the existing ones:

```go
var (
	// ... existing vars ...
	totalIncome           types.Money
	transactionCount      int
	biggestTransaction    dto.BiggestTransaction
	topMerchant           dto.TopMerchant
)
```

Add 4 new `g.Go()` calls before `g.Wait()`:

```go
g.Go(func() error {
	result, err := repository.GetTotalIncome(db.DB, profileId, startDate, endDate, currency)
	if err != nil {
		return err
	}
	mu.Lock()
	totalIncome = result
	mu.Unlock()
	return nil
})

g.Go(func() error {
	result, err := repository.GetTransactionCount(db.DB, profileId, startDate, endDate)
	if err != nil {
		return err
	}
	mu.Lock()
	transactionCount = result
	mu.Unlock()
	return nil
})

g.Go(func() error {
	result, err := repository.GetBiggestTransaction(db.DB, profileId, startDate, endDate, currency)
	if err != nil {
		return err
	}
	mu.Lock()
	biggestTransaction = result
	mu.Unlock()
	return nil
})

g.Go(func() error {
	result, err := repository.GetTopMerchant(db.DB, profileId, startDate, endDate, currency)
	if err != nil {
		return err
	}
	mu.Lock()
	topMerchant = result
	mu.Unlock()
	return nil
})
```

- [ ] **Step 2: Compute derived fields and populate QuickStats**

After `g.Wait()`, before building `res`, add:

```go
var savingsRate types.Money
if !totalIncome.IsZero() {
	savingsRate = types.Money(totalIncome.Sub(total).Div(totalIncome).Mul(decimal.NewFromInt(100)))
}

var avgTransaction types.Money
if transactionCount > 0 {
	avgTransaction = types.Money(total.Div(decimal.NewFromInt(int64(transactionCount))))
}

quickStats := dto.QuickStats{
	SavingsRate:        savingsRate,
	BiggestTransaction: biggestTransaction,
	TransactionCount:   transactionCount,
	TopMerchant:        topMerchant,
	AvgTransaction:     avgTransaction,
}
```

Then update the `res` assignment to include `QuickStats`:

```go
res := dto.AnalysisCharts{
	Categories:                spendByCategorySorted,
	CategoriesLastPeriod:      spendByCategorySortedLastPeriod,
	SpentPerDay:               spendPerDaySorted,
	SpentPerDayLastPeriod:     spendPerDaySortedLastPeriod,
	NextRecurringTransactions: nextRecurringTransactions,
	Total:                     total,
	QuickStats:                quickStats,
}
```

Add `github.com/shopspring/decimal` to imports if not already present.

- [ ] **Step 3: Verify compilation**

Run: `go build ./internal/analysis/...`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add internal/analysis/service/analysis_service.go
git commit -m "feat(analysis): wire quick stats into dashboard service"
```

---

### Task 4: Update Frontend Home.tsx

**Files:**
- Modify: `desktop/frontend/src/pages/Home.tsx`

- [ ] **Step 1: Add QuickStats type to existing interface**

In the `DashboardData` type, add `quick_stats`:

```typescript
interface DashboardData {
  // ... existing fields ...
  quick_stats: {
    savings_rate: number
    biggest_transaction: {
      name: string
      amount: number
      icon: string
      color: string
    }
    transaction_count: number
    top_merchant: {
      name: string
      amount: number
    }
    avg_transaction: number
  }
}
```

- [ ] **Step 2: Replace Quick Stats section**

Replace the existing Quick Stats card content (lines ~106-120) with:

```tsx
{/* Quick Stats */}
<div className="card bg-base-200 rounded-2xl p-4">
  <h3 className="text-sm font-semibold text-gray-300 mb-3">Quick Stats</h3>
  <div className="space-y-3">
    <div className="flex justify-between items-center">
      <span className="text-sm text-gray-400">Transactions this period</span>
      <span className="text-sm font-bold text-white">{data.quick_stats.transaction_count}</span>
    </div>
    <div className="flex justify-between items-center">
      <span className="text-sm text-gray-400">Top category</span>
      <div className="flex items-center gap-2">
        <CategoryBadge name={topCategory?.category_name || '-'} color={topCategory?.color || '#ccc'} />
        <span className="text-sm font-bold text-white">{formatCurrency(topCategory?.total_amount || 0)}</span>
      </div>
    </div>
    <div className="flex justify-between items-center">
      <span className="text-sm text-gray-400">Savings rate</span>
      <span className="text-sm font-bold text-emerald-400">{data.quick_stats.savings_rate.toFixed(1)}%</span>
    </div>
    <div className="flex justify-between items-center">
      <span className="text-sm text-gray-400">Biggest transaction</span>
      <div className="flex items-center gap-2">
        {data.quick_stats.biggest_transaction.icon && (
          <CategoryIcon icon={data.quick_stats.biggest_transaction.icon} color={data.quick_stats.biggest_transaction.color} />
        )}
        <span className="text-sm text-gray-300">{data.quick_stats.biggest_transaction.name}</span>
        <span className="text-sm font-bold text-white">{formatCurrency(data.quick_stats.biggest_transaction.amount)}</span>
      </div>
    </div>
    <div className="flex justify-between items-center">
      <span className="text-sm text-gray-400">Top merchant</span>
      <div className="flex items-center gap-2">
        <span className="text-sm text-gray-300">{data.quick_stats.top_merchant.name || '-'}</span>
        <span className="text-sm font-bold text-white">{formatCurrency(data.quick_stats.top_merchant.amount)}</span>
      </div>
    </div>
    <div className="flex justify-between items-center">
      <span className="text-sm text-gray-400">Avg transaction</span>
      <span className="text-sm font-bold text-white">{formatCurrency(data.quick_stats.avg_transaction)}</span>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Build frontend**

Run: `cd desktop/frontend && npm run build`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add desktop/frontend/src/pages/Home.tsx
git commit -m "feat(dashboard): render quick stats in frontend"
```

---

## Self-Review

**Spec coverage check:**
- ✅ Savings rate — Task 3 computes it
- ✅ Biggest transaction — Task 2 query + Task 3 wiring
- ✅ Transaction count — Task 2 query + Task 3 wiring
- ✅ Top merchant — Task 2 query + Task 3 wiring
- ✅ Avg transaction — Task 3 computes it from total/count
- ✅ All backend-side — no client calculations

**Placeholder scan:** No TBDs, all code provided.

**Type consistency:** `BiggestTransaction` and `TopMerchant` structs match between DTO, repository, and service.

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-05-10-dashboard-quick-stats-plan.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task
2. **Inline Execution** — I execute tasks in this session

Which approach?