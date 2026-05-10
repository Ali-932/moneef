# Insights / Analysis Page — Missing Charts Design

**Date:** 2026-05-09  
**Branch:** wali-integration  
**Status:** Approved

---

## Problem

The Insights page is incomplete. Three chart types visible in the design mockup are missing:

1. Donut chart for spending by category (with per-category colours)
2. Calendar heatmap for daily spending intensity
3. Recurring-this-month horizontal timeline

The existing backend and frontend already handle bar chart, line chart, and radar chart correctly. The gaps are specific and addable without restructuring existing code.

---

## Scope

- **In scope:** DTO patch, one new backend endpoint, three new frontend components, frontend type updates
- **Out of scope:** Refactoring existing endpoints, income analysis, patterns tab changes, radar/bar/line chart changes

---

## Backend Changes

### 1. `CategorySummary` DTO — add `icon` and `color`

**File:** `internal/analysis/dto/service_dto.go`

Current struct:
```go
type CategorySummary struct {
    CategoryID   uint        `json:"category_id"`
    CategoryName string      `json:"category_name"`
    TotalAmount  types.Money `json:"total_amount"`
    Percentage   types.Money `json:"percentage"`
}
```

Updated struct:
```go
type CategorySummary struct {
    CategoryID   uint        `json:"category_id"`
    CategoryName string      `json:"category_name"`
    TotalAmount  types.Money `json:"total_amount"`
    Percentage   types.Money `json:"percentage"`
    Icon         string      `json:"icon"`
    Color        string      `json:"color"`
}
```

**Repository change:** `internal/analysis/repository/analysis_repository.go`, function `GetTransactionsGroupedByCategory` — add `c.icon, c.color` to the SELECT clause:

```go
Select("c.id as category_id, c.name as category_name, c.icon as icon, c.color as color, SUM(tc.amount * COALESCE(cer.rate, 1)) as total_amount")
```

**"Others" synthetic entry:** The `othersCategory` literal in `internal/analysis/utils/analysis_utils.go` → `GetCategoriesSlicedAndSorted` must be updated to include the two new fields. The existing literal sets all four original fields inline; add `Icon` and `Color` to it:

```go
othersCategory := dto.CategorySummary{
    CategoryID:   0,
    CategoryName: "Others",
    TotalAmount:  othersTotal,
    Percentage:   types.MoneyFromInt(100).Mul(othersTotal.Div(total)),
    Icon:         "",
    Color:        "",
}
```

The frontend uses `#9CA3AF` (neutral grey) as fallback whenever `color === ""`.

**Percentage bug fix (in scope):** `GetCategoriesSlicedAndSorted` has a pre-existing bug where the second loop (lines 38–40) recalculates `Percentage` on range copies and silently discards results. Since the donut chart needs correct percentages, fix this as part of this work: remove the dead second loop entirely. The first loop (line 18) already sets `Percentage` correctly on each category before appending to `finalCategories`.

---

### 2. New endpoint: `GET /api/v1/recurrence/timeline`

**Route file:** `internal/routes/recurrence_routes.go`  
Add: `r.Get("/timeline", recurrences.GetTimelineHandler)`  
This is a new sub-path — not a replacement for `GET /` which remains `ListRecurrencesHandler`.

**Handler:** New plain package-level function `GetTimelineHandler` in `internal/recurrences/recurrence_handler.go` — matching the exact pattern of the existing `ListRecurrencesHandler`, `UpdateRecurrenceHandler`, `DeleteRecurrenceHandler` (all plain functions, no struct).

**Profile ID:** Read from JWT middleware context:
```go
profileID, ok := r.Context().Value("profileID").(uint)
if !ok {
    utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
    return
}
```

**Response DTO:** New type `RecurrenceOccurrence` in a new file `internal/recurrences/dto/recurrence_dto.go`. The `Currency` field is populated from `RecurrenceTemplate.CurrencyCode` (a plain string field on the model — do not join the `currencies` table):

```go
package dto

import (
    "moneef/pkg/types"
    "time"
)

type RecurrenceOccurrence struct {
    ID       uint        `json:"id"`
    Name     string      `json:"name"`
    Type     string      `json:"type"`     // "income" | "expense"
    Amount   types.Money `json:"amount"`
    Currency string      `json:"currency"`
    Icon     string      `json:"icon"`
    Color    string      `json:"color"`
    Date     time.Time   `json:"date"`
}
```

**Repository function:** Add `GetActiveRecurrenceTemplatesForProfile(profileID uint, monthStart time.Time) ([]models.RecurrenceTemplate, error)` to `internal/transactions/repository/recurrence_repository.go` — matching the pattern of all sibling functions in that file (use `db.DB` directly, no injected `*gorm.DB` parameter). GORM's default scope handles soft-delete automatically.

**Service logic** (new function `GetRecurrenceTimeline(profileID uint) ([]dto.RecurrenceOccurrence, error)` in `recurrence_service.go`):

1. Determine `monthStart` = first day of current month at 00:00:00 UTC, `monthEnd` = last day at 23:59:59 UTC
2. Fetch all `RecurrenceTemplate` rows for profile where `is_active = true` AND (`has_end_date = false` OR (`has_end_date = true` AND `end_date >= monthStart`)). `RecurrenceTemplate` embeds `gorm.Model` so GORM's default scope automatically filters out soft-deleted rows (`deleted_at IS NULL`) — no explicit filter needed. `end_date` is `*time.Time` (nullable); the SQL condition above handles the NULL case by only checking `end_date` when `has_end_date = true`.
3. For each template:
   - If `NextPaymentAmount` is nil, skip the template
   - Project occurrence dates using the **anchor-based walk**:
     - Use `NextDate` as the anchor. **Walk backward** (subtract one frequency step at a time) until `projected < monthStart` — this is the primary termination condition. If 400 steps are reached before `projected < monthStart`, log a warning and skip this template (safety abort for corrupt/pathological data only). **Walk forward** (add one frequency step at a time) from `NextDate` until `projected > monthEnd` (primary termination); same 400-step safety abort. Collect every date in `[monthStart, monthEnd]` from both walks.
     - For `monthly` and `yearly` frequencies, clamp the day-of-month to the target month's actual last day before constructing the date: `day := min(nextDate.Day(), daysInMonth(targetYear, targetMonth))` then `time.Date(targetYear, targetMonth, day, 0, 0, 0, 0, time.UTC)`. This prevents Go's silent date overflow (e.g. `time.Date(2026, 2, 31)` would normalise to March 3). Use a helper `daysInMonth(y int, m time.Month) int` that returns `time.Date(y, m+1, 0, ...).Day()`.
     - For `daily`, `weekly`, `bi-weekly`: `AddDate` is safe; no drift.
   - All projected occurrence dates have their time component zeroed to `00:00:00 UTC`
4. For each collected date, emit one `RecurrenceOccurrence` (same template metadata, projected date). When a template produces multiple occurrences (daily, weekly), all share the same `ID`. The frontend must use `id + date` as a composite React list key, not `id` alone.
5. Return all occurrences sorted by `Date ASC`

**Error states:**
- Missing/invalid JWT → HTTP 401 `"Unauthorized"`
- No active templates → return `[]`, HTTP 200
- DB error → HTTP 500 `"Failed to load timeline"`

**Example response:**
```json
[
  { "id": 1, "name": "Salary",  "type": "income",  "amount": "1000.00", "currency": "USD", "icon": "briefcase", "color": "#22C55E", "date": "2026-05-01T00:00:00Z" },
  { "id": 2, "name": "Rent",    "type": "expense", "amount": "350.00",  "currency": "USD", "icon": "home",      "color": "#EF4444", "date": "2026-05-01T00:00:00Z" }
]
```

---

## Frontend Changes

### 3. Type updates — `desktop/frontend/src/types/api.ts`

Add `icon` and `color` to `CategorySummary`:
```ts
export interface CategorySummary {
  category_id: number
  category_name: string
  total_amount: string
  percentage: string
  icon: string
  color: string
}
```

Add new type for the timeline:
```ts
export interface RecurrenceOccurrence {
  id: number
  name: string
  type: 'income' | 'expense'
  amount: string
  currency: string
  icon: string
  color: string
  date: string
}
```

**Note on API response shape:** The existing `get_spending_by_category` response wraps charts under the PascalCase key `"AnalysisCharts"` (matching the Go struct tag). Frontend access is:
```ts
response.AnalysisCharts.categories        // donut chart + radar
response.AnalysisCharts.spent_per_day     // heatmap + line chart
response.AnalysisCharts.total             // total expenses (string, e.g. "152.75")
```

### 4. New hook — `useRecurrenceTimeline.ts`

Calls `GET /api/v1/recurrence/timeline`. Returns `{ data: RecurrenceOccurrence[], loading: boolean, error: string | null }`. Follows the same pattern as `useInsights.ts` and `usePatterns.ts`.

### 5. Donut Chart (Spending by Category)

**Library:** recharts `PieChart` + `Pie` + `Cell` (already installed).

**Data source:** `response.AnalysisCharts.categories`

**Behaviour:**
- Each slice coloured by `category.color`; fallback `#9CA3AF` when `color === ""`
- Centre label: `response.AnalysisCharts.total` formatted with currency symbol, labelled **"Total Expenses"**
- Legend below: colour bullet + category name + percentage

### 6. Calendar Heatmap

**Data source:** `response.AnalysisCharts.spent_per_day`

The backend's `FillMissingDates` utility gap-fills this array so every calendar day in the selected period has exactly one entry (amount `"0.00"` on days with no spending). The frontend iterates this array directly — no additional gap-filling needed on the frontend.

**Layout:**
- 7-column CSS grid with column headers: **Mon Tue Wed Thu Fri Sat Sun**
- Grid column index (1-based, for CSS `grid-column`) for each day: `(new Date(entry.date).getDay() + 6) % 7 + 1` — maps Sunday=0 from `getDay()` to column 7, Monday=1 to column 1, etc. (ISO Monday-first)
- Apply `gridColumnStart` as an inline style **only on the first cell** in the grid to push it to the correct weekday column. No empty placeholder `<div>` elements needed — CSS grid handles the gap automatically.
- Only days present in `spent_per_day` are rendered; the array is already gap-filled by the backend so all days in the selected period are present.

**Colour intensity:**
```ts
const maxAmount = Math.max(...spent_per_day.map(d => parseFloat(d.amount)))
const intensity = maxAmount === 0 ? 0 : parseFloat(day.amount) / maxAmount
// Map intensity (0–1): 0 → #FEF2F2, 1 → #DC2626
// Use inline backgroundColor style per cell
```

**Implementation:** Plain CSS grid + inline styles — no external library.

### 7. Recurring This Month Timeline

**Data source:** `GET /api/v1/recurrence/timeline` via `useRecurrenceTimeline` hook.

**Always shows the current calendar month** regardless of the selected period at the top of the page.

**Layout:**
- Horizontal strip; x-axis shows day numbers 1 through last day of current month
- Derive `daysInMonth` using: `const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()` (note: JS `Date` months are 0-based, so `getMonth() + 1` gives next month, day `0` gives the last day of the current month)
- Each occurrence = a labelled pill positioned at `((date.getDate() - 1) / daysInMonth) * 100%` from the left
- Occurrences on the same day stack vertically
- Income pills: green (`#22C55E` background or border)
- Expense pills: red/pink (`#EF4444` background or border)
- Each pill shows: name + formatted amount (e.g. "Rent 350$")

**States:**
- Loading: skeleton strip
- Empty: "No recurring transactions this month"
- Error: "Unable to load recurring transactions"

---

## Data Flow Summary

```
Insights page mount
├── POST /api/v1/analysis/get_spending_by_category
│   └── response.AnalysisCharts.categories   → donut chart
│   └── response.AnalysisCharts.spent_per_day → heatmap, line chart
│   └── (existing) bar chart, radar chart
└── GET /api/v1/recurrence/timeline
    └── feeds: recurring this month timeline
```

---

## Testing Notes

- `tests/analysis_currency_test.go`: extend with a case asserting `icon` and `color` are present in `CategorySummary` for a category that has them set in the DB
- `tests/recurrences_test.go`: add `TestGetTimeline` covering:
  - Daily template: multiple occurrences within month
  - Monthly template where `NextDate` is in the future (after month end): backward projection still produces occurrence in current month
  - Monthly template where `NextDate` falls on day 31 (month-boundary drift check)
  - Template with `has_end_date=true` and `end_date` before month start: excluded
  - Template with `NextPaymentAmount = nil`: excluded
  - Income and expense templates both returned
  - Empty result when no active templates
  - Returns HTTP 401 when profileID missing from context
