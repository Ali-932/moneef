# Insights — Range-Adaptive Charts

**Date:** 2026-05-11
**Status:** Approved (brainstorming complete)
**Scope:** Frontend (primary) + minor backend refactor (recurrence timeline window)

## Problem

The Insights page now has a user-controlled date range, but most charts were not designed for arbitrary ranges. Three concrete failures surfaced:

1. **Cumulative Spending** chart overlays "this period" against "last period" as two line series on the same X-axis (calendar dates of the current period). The two series occupy different real dates, so the overlay is geometrically meaningless.
2. **Heatmap** is hardcoded to the current calendar month and breaks visually when the range exceeds 30 days or crosses month boundaries.
3. **Spending by Category — This Period vs Last** uses generic legend labels ("This period" / "Last period") with no actual dates, so users cannot tell what they are comparing against.

Underneath these specific bugs is a broader pattern: a single static chart layout is wrong because charts have different validity depending on the range size. A daily bar chart is useful for 30 days; pointless for 5 years. A monthly aggregation is useful for a year; absurd for a week.

## Goal

Make every chart on the Insights page produce a trustworthy, useful output for any date range the user can select, by adapting both **what is shown** and **how it is shown** to the range.

## Non-goals

- Adding a frontend test runner (none exists today).
- Backend aggregation of spending data — kept on the frontend.
- Changes to the Patterns tab.
- New chart types beyond what is enumerated here (no Sankey, treemap, area charts, etc.).
- Performance optimization for ranges >5 years (not warranted).
- Changing the date range selector UI (already shipped).

## Design decisions

| Decision | Choice |
|---|---|
| Adaptation strategy | Range-adaptive layout: which charts render and how depend on the range |
| Buckets | **Short** (≤31 days, daily resolution) and **Long** (>31 days, aggregated) |
| Long-bucket aggregation | Weekly for 32–180 days; monthly for >180 days |
| Comparison rule | Same length, immediately preceding period; legend labels show literal date ranges |
| Category visualizations | Donut (composition) + Bar (period comparison). Drop radar. |
| Trend chart | Single bar chart per range; optional dotted **previous-period average line** instead of misaligned dual series |
| Heatmap | Short bucket only; spans the actual selected range; multi-month grids stacked vertically when the range crosses month boundaries |
| Recurring | Decoupled from the date range. Always shows "next 30 days" timeline + upcoming list at a fixed position on both Overview and Analysis tabs |
| Overview layout | Lean: stat cards + category bars + sparkline + top patterns |
| Analysis layout | Deep: quick stats + donut + comparison bar + trend (with optional heatmap toggle for short ranges) |

## Bucketing rules

```
range_days = (end - start) in calendar days

short:   range_days ≤ 31  → daily resolution
long:    range_days > 31
  ├─ 32 ≤ range_days ≤ 180  → weekly aggregation (ISO-week start)
  └─ range_days > 180       → monthly aggregation
```

Resulting bar count, sanity bounds:
- Short: 1–31 bars
- Long-weekly: 5–26 bars
- Long-monthly: 7–60 bars (5 years is the practical maximum)

## Comparison rule

For any chart that compares against a previous period:

- `previousStart = start − duration`, `previousEnd = start`
- Legend and captions display **literal date ranges**: e.g., `"May 1 – May 31"` and `"Apr 1 – Apr 30"`
- The phrases "This period" / "Last period" are never used alone — always immediately followed by the explicit date range
- `formatDateRangeCaption()` from `utils/dateRange.ts` is the single source of truth for date formatting

## Chart-by-chart specification

### Spending Trend (replaces "Cumulative Spending")

Title is dynamic:
- Short bucket: **"Daily Spending"**
- Long-weekly: **"Weekly Spending"**
- Long-monthly: **"Monthly Spending"**

Render:
- Bar chart, X-axis = period labels (`"May 7"` for daily, `"Apr 7 – Apr 13"` for weekly, `"Apr 2026"` for monthly)
- Single series (no dual-line overlay)
- Optional horizontal **dotted reference line** at the previous period's average per bucket
- Caption below: `"Avg of previous period ({previousRange}): {amount}"`

**Heatmap toggle** appears only when bucket = short. The heatmap:
- Spans the actual selected range, not the current calendar month
- Iterates month by month over months touched by the range
- Renders a 7-column grid per month with a `<h3>` header
- Days outside `[start, end]` are rendered as transparent placeholder cells (preserves grid alignment)
- Days inside but with no spending are transparent
- Days with spending colored by intensity (existing logic)
- Multiple months stack vertically

### Spending by Category — Composition (donut)

Unchanged from current behavior except:
- Extracted into a standalone component
- Caption above the chart shows the active range

### Spending by Category — vs Previous Period (bar)

- Replaces the current bar chart that has unlabeled period legends
- Legend labels are literal date strings derived from the active range and its preceding period
- Bars sorted by current-period spend, descending
- Caption above the chart shows both ranges explicitly

### Quick Stats (new card on Analysis tab)

Surfaces existing `quick_stats` API data that the frontend currently ignores:

- 4-up grid: **Top Merchant**, **Biggest Transaction**, **Average Transaction**, **Transaction Count**
- Above the grid: **Savings Rate** as a single highlighted row, shown only when the API-returned `savings_rate` value is non-zero (the backend already returns 0 when income for the range is zero, which is the only case we want to hide). Hiding the row in that case avoids displaying "0%" without context.
- All values formatted with `formatMoney()`; all labels include the active range

### Sparkline (new component on Overview tab)

- ~40px tall, no axes, no tooltip
- Renders the same daily/weekly/monthly aggregation as the trend chart, in minimal form
- Caption below: the active range

### Recurring (decoupled, fixed position on both tabs)

Two cards, always rendered at the bottom of both Overview and Analysis tabs:

1. **Next 30 Days Timeline** — horizontal timeline of recurrence occurrences in the next 30 days from today
2. **Upcoming Recurring** — existing list of next future recurrences

A small caption above this section reads: `"Forward-looking · independent of selected range"`.

The backend endpoint backing `useRecurrenceTimeline` (currently hardcoded to "current calendar month") is changed to "next 30 days from now" — see Backend changes below.

## Page layouts

### Overview tab

1. Stat cards (Expenses, Net, Categories) — labels include the active range
2. Spending by Category — top 5 horizontal bars with "View all" link to Analysis
3. Sparkline trend
4. Top 3 Patterns
5. Recurring section (fixed)

### Analysis tab

1. Quick Stats card (savings rate row + 4-up grid)
2. Spending by Category — Composition (donut)
3. Spending by Category — vs Previous Period (bar)
4. Spending Trend (range-adaptive title; heatmap toggle if short)
5. Recurring section (fixed)

The radar chart is removed.

## Architecture

### New frontend utility

**`desktop/frontend/src/utils/insightsBucket.ts`** — pure functions, no React:

```ts
export type Bucket = 'short' | 'long'
export type Aggregation = 'daily' | 'weekly' | 'monthly'

export function getBucket(start: string, end: string): Bucket
export function getAggregation(start: string, end: string): Aggregation
export function aggregateByPeriod(
  data: AmountPerDay[],
  aggregation: Aggregation,
  rangeStart: string,
  rangeEnd: string
): { label: string; amount: number; periodStart: Date; periodEnd: Date }[]
export function calculatePreviousPeriodAverage(
  data: AmountPerDay[],
  aggregation: Aggregation
): number
export function getPreviousPeriodRange(start: string, end: string): { start: string; end: string }
```

### New frontend components

| Path | Purpose |
|---|---|
| `components/charts/TrendChart.tsx` | Range-adaptive bar chart with optional dotted average line |
| `components/charts/Heatmap.tsx` | Multi-month-aware calendar heatmap |
| `components/charts/CategoryComparisonBar.tsx` | Bar chart with explicit date legends |
| `components/charts/CategoryDonut.tsx` | Extracted donut |
| `components/charts/Sparkline.tsx` | Minimal trend sparkline |
| `components/cards/QuickStatsCard.tsx` | Surfaces existing `quick_stats` API data |

### Modified frontend files

- **`types/api.ts`** — add `QuickStats` interface (the Go DTO already returns it under `quick_stats`); add `quick_stats` field to `AnalysisCharts`
- **`hooks/useRecurrenceTimeline.ts`** — no signature change required (already returns whatever the backend gives)
- **`pages/Insights.tsx`** — replace inline charts with new components; reorganize Overview and Analysis layouts; move Recurring section; delete radar code

### Backend changes

**`internal/transactions/service/transaction_service.go`** — `GetRecurrenceTimeline`:

- Change the window from `[monthStart, monthEnd]` to `[today, today + 30 days]`
- Function signature unchanged; only the internal date math changes
- The backward-looking projection loop is no longer needed (we only want future occurrences from today)

This is the only backend change required. The `quick_stats` data is already returned by `analysis_service.go` and just needs to be consumed on the frontend.

## Risks and mitigations

1. **`useRecurrenceTimeline` consumers** — verified to be used only in `Insights.tsx`. Safe to change the backend window.
2. **Heatmap height when range spans 3+ months** — multi-month vertical stacking can make the page long. Acceptable tradeoff: heatmap is opt-in via toggle, and only available for short bucket (≤31 days), so the worst case is ~2 stacked grids when the 31-day range crosses a month boundary.
3. **Savings rate semantics** — service returns 0 when income is zero. UI must hide the row in that case rather than rendering "0%".
4. **`quick_stats` consumption** — verified the Go service builds it (`analysis_service.go:171`) and the DTO has `json:"quick_stats"` (`service_dto.go:35`). Safe to consume from frontend.
5. **Bar density at edge cases** — a 5-year range produces 60 monthly bars. Visually dense but acceptable; users selecting that range expect a lot of data.

## Testing plan

No frontend test runner exists; not introducing one. Verification is manual + type-checking + production build.

### Type/build gates

- `go build ./...` — must pass (backend signature unchanged)
- `go test -run TestPattern ./tests/` — must pass (no related changes)
- `cd desktop/frontend && ./node_modules/.bin/tsc --noEmit` — must pass after each phase
- `cd desktop/frontend && npm run build` — must pass at the end

### Manual verification matrix

For each range, verify the page renders without error and the chart set matches the bucket:

| Range | Bucket | Expected charts |
|---|---|---|
| This Month (~10 days mid-month) | short | Daily trend; heatmap toggle (1 month grid) |
| Last 30 Days | short | Daily trend; heatmap toggle (potentially 2 month grids stacked) |
| Last 3 Months | long-weekly | Weekly trend; no heatmap toggle |
| This Year (~130 days mid-year) | long-weekly | Weekly trend (~19 bars) |
| All Time (>180 days) | long-monthly | Monthly trend |
| Custom range crossing year boundary | long-{auto} | Correct aggregation; correct labels |

For each:
- Comparison labels show literal dates, never "This period" / "Last period" alone
- Stat cards mention the range in their captions
- Recurring section unchanged across all ranges (proves decoupling)
- Quick stats card hides Savings Rate row when income is zero

### Known unsupported manual cases

- Ranges <1 day: clamped to 1 day by date-input semantics.
- Range with end before start: not currently prevented by the UI; backend will return empty data. Out of scope for this work.

## Implementation order

7 phases, each ending in a clean compile:

1. **Pure utilities** — `insightsBucket.ts`. No UI changes.
2. **Type fix + backend recurrence window** — `types/api.ts` adds `QuickStats`; `transaction_service.go` changes window to "next 30 days from today."
3. **Extract existing charts** — move donut into `CategoryDonut.tsx`. Visual parity.
4. **New chart components** — `TrendChart`, `Heatmap`, `CategoryComparisonBar`, `Sparkline`, `QuickStatsCard`. Built in isolation, exported but not yet wired.
5. **Wire into Insights.tsx** — replace old inline charts; delete radar + old heatmap code; reorganize Overview to lean layout; move Recurring section.
6. **Range-aware labels** — update stat card and chart titles to include range caption.
7. **Verification** — `tsc --noEmit`, `npm run build`, manual matrix above.

## File-by-file summary

### New files

- `desktop/frontend/src/utils/insightsBucket.ts`
- `desktop/frontend/src/components/charts/TrendChart.tsx`
- `desktop/frontend/src/components/charts/Heatmap.tsx`
- `desktop/frontend/src/components/charts/CategoryComparisonBar.tsx`
- `desktop/frontend/src/components/charts/CategoryDonut.tsx`
- `desktop/frontend/src/components/charts/Sparkline.tsx`
- `desktop/frontend/src/components/cards/QuickStatsCard.tsx`

### Modified files

- `desktop/frontend/src/types/api.ts` — add `QuickStats` interface and field
- `desktop/frontend/src/pages/Insights.tsx` — major restructuring
- `internal/transactions/service/transaction_service.go` — `GetRecurrenceTimeline` window change

### Deleted code (within `Insights.tsx`)

- Radar chart block
- Inline single-month heatmap logic (replaced by `Heatmap.tsx`)
- `cumulativeTab` state
- Misaligned "Last period" line series
