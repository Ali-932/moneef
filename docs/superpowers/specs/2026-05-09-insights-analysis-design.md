# Insights / Analysis Page — Missing Charts Design

**Date:** 2026-05-09  
**Branch:** wali-integration  
**Status:** Approved

---

## Problem

The Insights page is broken/incomplete. The Analysis tab is missing three chart types visible in the design mockup:

1. Donut chart for spending by category (with colours per category)
2. Calendar heatmap for daily spending intensity
3. Recurring-this-month horizontal timeline

The existing backend and frontend handle bar chart, line chart, and radar chart correctly. The gaps are specific and addable without restructuring the existing code.

---

## Scope

- **In scope:** DTO patch, one new backend endpoint, three new frontend components
- **Out of scope:** Refactoring existing endpoints, income analysis, patterns tab changes, radar/bar/line chart changes

---

## Backend Changes

### 1. `CategorySummary` DTO — add `icon` and `color`

**File:** `internal/analysis/dto/handler_dto.go`

```go
type CategorySummary struct {
    CategoryID   int         `json:"category_id"`
    CategoryName string      `json:"category_name"`
    TotalAmount  types.Money `json:"total_amount"`
    Percentage   types.Money `json:"percentage"`
    Icon         string      `json:"icon"`
    Color        string      `json:"color"`
}
```

**Repository change:** `internal/analysis/repository/` (or whichever file runs `GetSpendingByCategory`) — add `c.icon, c.color` to the SELECT and scan into the struct. The synthetic "Others" entry (category_id: 0) gets empty strings for both fields.

### 2. New endpoint: `GET /api/v1/recurrence/timeline`

**Purpose:** Return projected occurrence dates for all active recurring templates within the current calendar month, for both income and expense types.

**Handler:** `internal/recurrences/recurrence_handler.go` — new `GetTimelineHandler`

**Service logic:**
1. Fetch all active `RecurrenceTemplate` rows for the profile (exclude soft-deleted and templates where `has_end_date=true AND end_date < today`)
2. For each template, starting from `template.NextDate`, step forward by frequency until the date exceeds the last day of the current month. Collect all dates that fall within the current month.
3. Return a flat list of occurrences sorted by date ascending.

**Frequency step logic:**
```
daily      → add 1 day
weekly     → add 7 days
bi-weekly  → add 14 days
monthly    → add 1 month
yearly     → add 1 year
```

**Response DTO:**
```json
[
  {
    "id": 1,
    "name": "Rent",
    "type": "expense",
    "amount": "350.00",
    "currency": "USD",
    "icon": "home",
    "color": "#FF5733",
    "date": "2026-05-01"
  }
]
```

**Route:** `internal/routes/recurrence_routes.go` — add `GET /` handler (currently used for listing templates; this is a new sub-path `/timeline`)

---

## Frontend Changes

All components are added to the existing Insights page. The page already has an `Analysis` tab structure; components are placed within it.

### 3. Donut Chart (Spending by Category)

**Location:** Replaces the horizontal progress-bar category list in the Overview/Analysis section.

**Library:** recharts `PieChart` + `Pie` + `Cell` (already installed)

**Data source:** `AnalysisCharts.categories` from the existing `get_spending_by_category` response.

**Behaviour:**
- Each slice coloured by `category.color`
- "Others" slice (category_id: 0) uses a neutral grey (`#9CA3AF`)
- Centre label: total formatted in user currency
- Legend below: category name + percentage, matching the mockup layout

### 4. Calendar Heatmap

**Location:** New section below the donut chart, within the Analysis tab.

**Data source:** `AnalysisCharts.spent_per_day` from the existing response — no new API call.

**Behaviour:**
- Grid of day cells for the selected period
- Colour intensity: `amount / max(amounts in period)` mapped from light pink → dark red
- Days with `amount === 0` render as the lightest neutral shade
- Layout: days of week as columns, weeks as rows (matching the mockup)
- Implementation: CSS grid with inline `opacity` or `backgroundColor` per cell — no external library

### 5. Recurring This Month Timeline

**Location:** Bottom of the Insights page, always shows current calendar month regardless of selected period.

**Data source:** `GET /api/v1/recurrence/timeline` — new dedicated hook `useRecurrenceTimeline.ts`

**Behaviour:**
- Horizontal strip with day numbers 1–(28/29/30/31) on x-axis
- Each occurrence is a labelled pill positioned at its projected date
- Income pills: green background
- Expense pills: red/pink background
- Each pill shows: name + formatted amount
- Overlapping pills on the same day stack vertically

---

## Data Flow Summary

```
Page load
├── POST /api/v1/analysis/get_spending_by_category
│   └── response feeds: donut chart, radar, bar chart, line chart, heatmap
└── GET /api/v1/recurrence/timeline
    └── response feeds: recurring this month timeline
```

---

## Error States

- If `categories` is empty → show "No spending data for this period" placeholder in donut
- If `spent_per_day` is empty → render heatmap with all grey cells
- If timeline fetch fails → show "Unable to load recurring transactions" inline message
- Division by zero in heatmap intensity (all amounts are 0) → all cells render as lightest shade

---

## Testing Notes

- Existing `tests/analysis_currency_test.go` should be extended with a case asserting `icon` and `color` are present in `CategorySummary`
- New `GetTimelineHandler` should be covered by a test in `tests/recurrences_test.go` asserting correct projection for each frequency type (daily, weekly, bi-weekly, monthly, yearly) and that past-end-date templates are excluded
