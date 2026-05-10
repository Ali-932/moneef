# Insights — Range-Adaptive Charts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every Insights chart trustworthy and useful for any selected date range by adapting which charts render and how they aggregate data based on a Short (≤31 days) vs Long (>31 days) bucket.

**Architecture:** Pure client-side bucketing logic in a new util module. New focused chart components replacing the inline rendering in `Insights.tsx`. Backend touches limited to `GetRecurrenceTimeline` window change. Comparison charts use literal date-range labels everywhere via the existing `formatDateRangeCaption()`.

**Tech Stack:** Go 1.24 (backend), React 18 + TypeScript + Vite + Tailwind + DaisyUI + Recharts (frontend). No frontend test runner — verification is `tsc --noEmit` + `npm run build` + manual matrix per the spec.

**Note on TDD deviation:** The frontend has no test runner today, and the spec explicitly excludes adding one (per AGENTS.md, user instructions take priority over default skill behavior). Backend tasks use TDD; frontend tasks use type-check + build + visual smoke tests. This is intentional and approved in the spec.

**Spec:** `docs/superpowers/specs/2026-05-11-insights-range-adaptive-charts-design.md`

---

## File Structure (decomposition)

**New frontend files (one responsibility each):**
- `desktop/frontend/src/utils/insightsBucket.ts` — pure functions for bucket detection, aggregation, previous-period math
- `desktop/frontend/src/components/charts/CategoryDonut.tsx` — donut + center total + legend
- `desktop/frontend/src/components/charts/CategoryComparisonBar.tsx` — bar chart with literal date legend
- `desktop/frontend/src/components/charts/TrendChart.tsx` — bar chart with optional dotted average line
- `desktop/frontend/src/components/charts/Heatmap.tsx` — multi-month-aware calendar heatmap
- `desktop/frontend/src/components/charts/Sparkline.tsx` — 40px no-axis line
- `desktop/frontend/src/components/cards/QuickStatsCard.tsx` — 4-up grid + optional savings rate row
- `desktop/frontend/src/components/insights/RecurringSection.tsx` — fixed-position recurring block (timeline + upcoming list)

**Modified frontend files:**
- `desktop/frontend/src/types/api.ts` — add `QuickStats` interface and `quick_stats` field
- `desktop/frontend/src/pages/Insights.tsx` — restructured into lean Overview + deep Analysis using new components

**Modified backend files:**
- `internal/transactions/service/transaction_service.go` — `GetRecurrenceTimeline` window: month → next 30 days

---

## Task 1: Backend — change recurrence timeline window to "next 30 days"

**Files:**
- Modify: `internal/transactions/service/transaction_service.go:372-441` (`GetRecurrenceTimeline`)
- Test: `tests/recurrence_timeline_test.go` (new file if missing; check first)

This is the only backend change. We TDD it.

- [ ] **Step 1: Verify whether a recurrence timeline test file exists**

```bash
ls tests/ | grep -i recurrence
```
Expected: shows `recurrences_test.go` (which is currently broken per AGENTS.md gotchas) or no recurrence-related test file.

- [ ] **Step 2: Read the existing function to understand the loop semantics**

```bash
sed -n '370,441p' internal/transactions/service/transaction_service.go
```
Expected: see `monthStart`/`monthEnd` as the window, then a backward loop and a forward loop populating `dateSet`.

- [ ] **Step 3: Write a failing test**

Create `tests/recurrence_timeline_window_test.go`:

```go
package tests

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/internal/transactions/service"
	"moneef/pkg/types"
)

func TestRecurrenceTimelineNext30Days(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	now := time.Now().UTC()

	// Template that next fires 5 days from now → must be included
	amt := MoneyFromFloat(50.0)
	tplSoon := &models.RecurrenceTemplate{
		ProfileID:         testProfileID,
		Name:              "Soon",
		Type:              "expense",
		Frequency:         "monthly",
		NextDate:          now.AddDate(0, 0, 5),
		NextPaymentAmount: &amt,
		CurrencyCode:      "USD",
		IsActive:          true,
	}
	require.NoError(t, db.DB.Create(tplSoon).Error)

	// Template that next fires 60 days from now → must NOT be included (beyond 30-day window)
	amt2 := MoneyFromFloat(75.0)
	tplLater := &models.RecurrenceTemplate{
		ProfileID:         testProfileID,
		Name:              "Later",
		Type:              "expense",
		Frequency:         "monthly",
		NextDate:          now.AddDate(0, 0, 60),
		NextPaymentAmount: &amt2,
		CurrencyCode:      "USD",
		IsActive:          true,
	}
	require.NoError(t, db.DB.Create(tplLater).Error)

	occurrences, err := service.GetRecurrenceTimeline(testProfileID)
	require.NoError(t, err)

	var sawSoon, sawLater bool
	for _, occ := range occurrences {
		if occ.Name == "Soon" {
			sawSoon = true
			// Must be within next 30 days from today (inclusive)
			assert.False(t, occ.Date.Before(now.Truncate(24*time.Hour)), "Soon occurrence should not be in the past")
			assert.True(t, occ.Date.Before(now.AddDate(0, 0, 31)), "Soon occurrence should be within next 30 days")
		}
		if occ.Name == "Later" {
			sawLater = true
		}
	}

	assert.True(t, sawSoon, "Expected 'Soon' (5 days out) to be in next-30-days window")
	assert.False(t, sawLater, "Expected 'Later' (60 days out) to be excluded from next-30-days window")

	_ = types.Money{}
}
```

- [ ] **Step 4: Run the test — expect failure (current behavior uses calendar month)**

```bash
go test -run TestRecurrenceTimelineNext30Days ./tests/
```
Expected: FAIL. Either `Later` shows up (because it's within current calendar month) or `Soon` doesn't (if today is late in the month and 5 days crosses the boundary). Capture the failure message.

- [ ] **Step 5: Update `GetRecurrenceTimeline` to use "today → today + 30 days"**

Modify `internal/transactions/service/transaction_service.go` lines 372–406. Replace the function body up to (and including) the backward loop with this:

```go
func GetRecurrenceTimeline(profileID uint) ([]dto.RecurrenceOccurrence, error) {
	now := time.Now().UTC()
	windowStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	windowEnd := windowStart.AddDate(0, 0, 30).Add(23*time.Hour + 59*time.Minute + 59*time.Second)

	templates, err := repository.GetActiveRecurrenceTemplatesForProfile(profileID, windowStart)
	if err != nil {
		return nil, err
	}

	var occurrences []dto.RecurrenceOccurrence

	for _, tpl := range templates {
		if tpl.NextPaymentAmount == nil {
			continue
		}

		anchor := time.Date(tpl.NextDate.Year(), tpl.NextDate.Month(), tpl.NextDate.Day(), 0, 0, 0, 0, time.UTC)
		freq := tpl.Frequency

		dateSet := make(map[string]time.Time)

		// Walk backwards only as far as the window start (in case anchor is in the future,
		// we still need to handle templates whose NextDate is between windowStart and windowEnd)
		projected := anchor
		steps := 0
		for !projected.Before(windowStart) && steps < 400 {
			if !projected.Before(windowStart) && !projected.After(windowEnd) {
				dateSet[projected.Format("2006-01-02")] = projected
			}
			projected = subFrequency(projected, freq)
			steps++
		}
		if steps >= 400 {
			log.Printf("⚠️ [SERVICE] Recurrence template %d exceeded 400 backward steps, skipping", tpl.ID)
			continue
		}
```

Then continue with the existing forward-projection loop (lines ~408-441) UNCHANGED, but rename `monthEnd` → `windowEnd` and `monthStart` → `windowStart` in those lines too. Read the full function after editing to confirm only those identifier renames remain.

- [ ] **Step 6: Run the test — expect pass**

```bash
go test -run TestRecurrenceTimelineNext30Days ./tests/
```
Expected: PASS.

- [ ] **Step 7: Run the existing pattern tests to confirm no regression**

```bash
go test -run TestPattern ./tests/
```
Expected: PASS.

- [ ] **Step 8: Build the whole backend**

```bash
go build ./...
```
Expected: no output, exit 0.

- [ ] **Step 9: Commit**

```bash
git add internal/transactions/service/transaction_service.go tests/recurrence_timeline_window_test.go
git commit -m "feat(transactions): switch recurrence timeline to next-30-days window

Decouples the recurrence timeline from the calendar month so the frontend
Insights page can render a stable forward-looking view independent of any
selected analysis date range."
```

---

## Task 2: Frontend — add `QuickStats` to API types

**Files:**
- Modify: `desktop/frontend/src/types/api.ts`

- [ ] **Step 1: Read the current `AnalysisCharts` interface**

```bash
sed -n '99,120p' desktop/frontend/src/types/api.ts
```
Expected: see `AnalysisCharts` with `categories`, `categories_last_period`, `spent_per_day`, `spent_per_day_last_period`, `next_recurring_transactions`, `total`. No `quick_stats` field.

- [ ] **Step 2: Add `QuickStats` interface and field**

In `desktop/frontend/src/types/api.ts`, find the `AnalysisCharts` interface and replace it with:

```ts
export interface QuickStats {
  savings_rate: string
  biggest_transaction: {
    name: string
    amount: string
    icon: string
    color: string
  }
  transaction_count: number
  top_merchant: {
    name: string
    amount: string
  }
  avg_transaction: string
}

export interface AnalysisCharts {
  categories: CategorySummary[]
  categories_last_period: CategorySummary[]
  spent_per_day: AmountPerDay[]
  spent_per_day_last_period: AmountPerDay[]
  next_recurring_transactions: NextRecurringTransaction[]
  total: string
  quick_stats: QuickStats
}
```

- [ ] **Step 3: Type-check**

```bash
cd desktop/frontend && ./node_modules/.bin/tsc --noEmit
```
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/types/api.ts
git commit -m "types(api): surface QuickStats in AnalysisCharts response

The backend already returns quick_stats; expose it in the TypeScript
types so the frontend can render the new Quick Stats card."
```

---

## Task 3: Frontend — create `insightsBucket.ts` utility

**Files:**
- Create: `desktop/frontend/src/utils/insightsBucket.ts`

- [ ] **Step 1: Create the file**

Create `desktop/frontend/src/utils/insightsBucket.ts` with the full content below:

```ts
import type { AmountPerDay } from '../types/api'

export type Bucket = 'short' | 'long'
export type Aggregation = 'daily' | 'weekly' | 'monthly'

const SHORT_MAX_DAYS = 31
const WEEKLY_MAX_DAYS = 180

function diffInDays(start: string, end: string): number {
  const s = new Date(start).getTime()
  const e = new Date(end).getTime()
  return Math.max(1, Math.round((e - s) / (1000 * 60 * 60 * 24)))
}

export function getBucket(start: string, end: string): Bucket {
  return diffInDays(start, end) <= SHORT_MAX_DAYS ? 'short' : 'long'
}

export function getAggregation(start: string, end: string): Aggregation {
  const days = diffInDays(start, end)
  if (days <= SHORT_MAX_DAYS) return 'daily'
  if (days <= WEEKLY_MAX_DAYS) return 'weekly'
  return 'monthly'
}

export function getPreviousPeriodRange(start: string, end: string): { start: string; end: string } {
  const s = new Date(start)
  const e = new Date(end)
  const ms = e.getTime() - s.getTime()
  const prevEnd = new Date(s.getTime())
  const prevStart = new Date(s.getTime() - ms)
  return { start: prevStart.toISOString(), end: prevEnd.toISOString() }
}

function startOfWeek(d: Date): Date {
  // ISO week: Monday as start
  const day = d.getUTCDay()
  const diff = (day === 0 ? -6 : 1 - day)
  const out = new Date(d)
  out.setUTCDate(d.getUTCDate() + diff)
  out.setUTCHours(0, 0, 0, 0)
  return out
}

function startOfMonth(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1))
}

function fmtDay(d: Date): string {
  return d.toLocaleDateString('en', { month: 'short', day: 'numeric' })
}

function fmtMonth(d: Date): string {
  return d.toLocaleDateString('en', { month: 'short', year: 'numeric' })
}

export interface AggregatedBar {
  label: string
  amount: number
  periodStart: Date
  periodEnd: Date
}

export function aggregateByPeriod(
  data: AmountPerDay[],
  aggregation: Aggregation
): AggregatedBar[] {
  if (aggregation === 'daily') {
    return data.map((d) => {
      const date = new Date(d.date)
      return {
        label: fmtDay(date),
        amount: parseFloat(d.amount),
        periodStart: date,
        periodEnd: date,
      }
    })
  }

  const buckets = new Map<string, { sum: number; start: Date; end: Date }>()

  for (const d of data) {
    const date = new Date(d.date)
    let bucketStart: Date
    let bucketEnd: Date

    if (aggregation === 'weekly') {
      bucketStart = startOfWeek(date)
      bucketEnd = new Date(bucketStart)
      bucketEnd.setUTCDate(bucketStart.getUTCDate() + 6)
    } else {
      bucketStart = startOfMonth(date)
      bucketEnd = new Date(Date.UTC(bucketStart.getUTCFullYear(), bucketStart.getUTCMonth() + 1, 0))
    }

    const key = bucketStart.toISOString()
    const existing = buckets.get(key)
    const value = parseFloat(d.amount)
    if (existing) {
      existing.sum += value
    } else {
      buckets.set(key, { sum: value, start: bucketStart, end: bucketEnd })
    }
  }

  const sorted = Array.from(buckets.values()).sort(
    (a, b) => a.start.getTime() - b.start.getTime()
  )

  return sorted.map((b) => ({
    label:
      aggregation === 'weekly'
        ? `${fmtDay(b.start)} – ${fmtDay(b.end)}`
        : fmtMonth(b.start),
    amount: b.sum,
    periodStart: b.start,
    periodEnd: b.end,
  }))
}

export function calculatePreviousPeriodAverage(
  data: AmountPerDay[],
  aggregation: Aggregation
): number {
  const aggregated = aggregateByPeriod(data, aggregation)
  if (aggregated.length === 0) return 0
  const sum = aggregated.reduce((acc, b) => acc + b.amount, 0)
  return sum / aggregated.length
}
```

- [ ] **Step 2: Type-check**

```bash
cd desktop/frontend && ./node_modules/.bin/tsc --noEmit
```
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/utils/insightsBucket.ts
git commit -m "feat(insights): add bucketing util for range-adaptive charts

Pure functions for short/long bucket detection, daily/weekly/monthly
aggregation, previous-period range computation, and previous-period
average calculation. Used by upcoming chart components."
```

---

## Task 4: Frontend — extract `CategoryDonut` component

**Files:**
- Create: `desktop/frontend/src/components/charts/CategoryDonut.tsx`

- [ ] **Step 1: Create the directory and file**

```bash
mkdir -p desktop/frontend/src/components/charts
```

Then create `desktop/frontend/src/components/charts/CategoryDonut.tsx`:

```tsx
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from 'recharts'
import { formatMoney } from '../../utils/money'

export interface DonutSlice {
  name: string
  amount: number
  pct: number
  color: string
}

interface CategoryDonutProps {
  data: DonutSlice[]
  total: number
  currency: string
  caption?: string
}

export function CategoryDonut({ data, total, currency, caption }: CategoryDonutProps) {
  if (data.length === 0) {
    return <p className="text-sm text-gray-400">No data for this period.</p>
  }

  return (
    <div className="flex flex-col items-center gap-3">
      {caption && <span className="text-[0.65rem] text-gray-400 self-end">{caption}</span>}
      <div className="relative w-full h-[240px]">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={data}
              dataKey="amount"
              nameKey="name"
              innerRadius={70}
              outerRadius={100}
              paddingAngle={2}
              stroke="none"
            >
              {data.map((d, i) => (
                <Cell key={`cell-${i}`} fill={d.color} />
              ))}
            </Pie>
            <Tooltip formatter={(value: any) => formatMoney(Number(value), currency)} />
          </PieChart>
        </ResponsiveContainer>
        <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
          <div className="text-[0.65rem] text-gray-400">Total Expenses</div>
          <div className="text-[0.85rem] font-bold">{formatMoney(total, currency)}</div>
        </div>
      </div>
      <div className="flex flex-wrap gap-x-4 gap-y-1 justify-center w-full">
        {data.map((d) => (
          <div key={d.name} className="flex items-center gap-1.5 text-[0.7rem]">
            <span className="inline-block w-2 h-2 rounded-full" style={{ backgroundColor: d.color }} />
            <span>{d.name}</span>
            <span className="text-gray-400">{d.pct.toFixed(1)}%</span>
          </div>
        ))}
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Type-check**

```bash
cd desktop/frontend && ./node_modules/.bin/tsc --noEmit
```
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/components/charts/CategoryDonut.tsx
git commit -m "feat(charts): extract CategoryDonut component

Self-contained donut chart with center total + legend. Identical
visual behavior to the inline version in Insights.tsx; will replace
that block in a later task."
```

---

## Task 5: Frontend — create `CategoryComparisonBar` component

**Files:**
- Create: `desktop/frontend/src/components/charts/CategoryComparisonBar.tsx`

- [ ] **Step 1: Create the file**

```tsx
import { BarChart, Bar, XAxis, YAxis, Tooltip, Legend, ResponsiveContainer } from 'recharts'
import { formatMoney } from '../../utils/money'

export interface ComparisonRow {
  name: string
  current: number
  previous: number
}

interface CategoryComparisonBarProps {
  data: ComparisonRow[]
  currency: string
  currentLabel: string  // e.g. "May 1 – May 31"
  previousLabel: string // e.g. "Apr 1 – Apr 30"
}

export function CategoryComparisonBar({
  data,
  currency,
  currentLabel,
  previousLabel,
}: CategoryComparisonBarProps) {
  if (data.length === 0) {
    return <p className="text-sm text-gray-400">No data for this period.</p>
  }

  // Sort by current descending
  const sorted = [...data].sort((a, b) => b.current - a.current)

  return (
    <ResponsiveContainer width="100%" height={260}>
      <BarChart data={sorted} barCategoryGap="20%" margin={{ top: 10, right: 10, left: 10, bottom: 5 }}>
        <XAxis dataKey="name" tick={{ fontSize: 10, fill: '#9CA3AF' }} />
        <YAxis hide />
        <Tooltip
          formatter={(value: any) => formatMoney(Number(value), currency)}
          contentStyle={{
            backgroundColor: '#18181b',
            border: '1px solid #27272a',
            borderRadius: '8px',
            color: '#e4e4e7',
          }}
          itemStyle={{ color: '#e4e4e7', fontSize: '0.75rem' }}
          labelStyle={{ color: '#9CA3AF', fontSize: '0.75rem' }}
        />
        <Legend wrapperStyle={{ fontSize: '0.75rem', color: '#9CA3AF' }} />
        <Bar dataKey="current" name={currentLabel} fill="#2563EB" radius={[4, 4, 0, 0]} barSize={40} />
        <Bar dataKey="previous" name={previousLabel} fill="#DC2626" radius={[4, 4, 0, 0]} barSize={40} />
      </BarChart>
    </ResponsiveContainer>
  )
}
```

- [ ] **Step 2: Type-check**

```bash
cd desktop/frontend && ./node_modules/.bin/tsc --noEmit
```
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/components/charts/CategoryComparisonBar.tsx
git commit -m "feat(charts): add CategoryComparisonBar with literal date labels

Period legends are explicit date ranges instead of generic 'This/Last
period' strings, making the comparison meaningful regardless of the
selected analysis range."
```

---

## Task 6: Frontend — create `TrendChart` component

**Files:**
- Create: `desktop/frontend/src/components/charts/TrendChart.tsx`

- [ ] **Step 1: Create the file**

```tsx
import { BarChart, Bar, XAxis, YAxis, Tooltip, ReferenceLine, ResponsiveContainer } from 'recharts'
import { formatMoney } from '../../utils/money'
import type { AggregatedBar } from '../../utils/insightsBucket'

interface TrendChartProps {
  bars: AggregatedBar[]
  currency: string
  previousAverage?: number
  previousAverageLabel?: string  // e.g. "Avg of Apr 1 – Apr 30"
}

export function TrendChart({ bars, currency, previousAverage, previousAverageLabel }: TrendChartProps) {
  if (bars.length === 0) {
    return <p className="text-sm text-gray-400">No data for this period.</p>
  }

  return (
    <div className="flex flex-col gap-2">
      <ResponsiveContainer width="100%" height={220}>
        <BarChart data={bars} margin={{ top: 10, right: 10, left: 10, bottom: 5 }}>
          <XAxis dataKey="label" tick={{ fontSize: 10, fill: '#9CA3AF' }} />
          <YAxis hide />
          <Tooltip
            formatter={(value: any) => formatMoney(Number(value), currency)}
            contentStyle={{
              backgroundColor: '#18181b',
              border: '1px solid #27272a',
              borderRadius: '8px',
              color: '#e4e4e7',
            }}
            itemStyle={{ color: '#e4e4e7', fontSize: '0.75rem' }}
            labelStyle={{ color: '#9CA3AF', fontSize: '0.75rem' }}
          />
          <Bar dataKey="amount" fill="#6B5CE7" radius={[4, 4, 0, 0]} />
          {previousAverage !== undefined && previousAverage > 0 && (
            <ReferenceLine
              y={previousAverage}
              stroke="#9CA3AF"
              strokeDasharray="4 4"
              ifOverflow="extendDomain"
            />
          )}
        </BarChart>
      </ResponsiveContainer>
      {previousAverage !== undefined && previousAverage > 0 && previousAverageLabel && (
        <div className="text-[0.65rem] text-gray-400 text-center">
          {previousAverageLabel}: {formatMoney(previousAverage, currency)}
        </div>
      )}
    </div>
  )
}
```

- [ ] **Step 2: Type-check**

```bash
cd desktop/frontend && ./node_modules/.bin/tsc --noEmit
```
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/components/charts/TrendChart.tsx
git commit -m "feat(charts): add TrendChart with optional previous-period average line

Single-series bar chart that renders pre-aggregated bars (daily/weekly/
monthly). Optional dotted reference line shows the average of the
previous period — replaces the misaligned dual-line overlay in the
old Cumulative Spending chart."
```

---

## Task 7: Frontend — create `Heatmap` component (multi-month-aware)

**Files:**
- Create: `desktop/frontend/src/components/charts/Heatmap.tsx`

- [ ] **Step 1: Create the file**

```tsx
import { useMemo } from 'react'
import { formatMoney } from '../../utils/money'
import type { AmountPerDay } from '../../types/api'

interface HeatmapProps {
  data: AmountPerDay[]
  rangeStart: string
  rangeEnd: string
  currency: string
}

interface MonthGrid {
  year: number
  month: number  // 0-11
  monthLabel: string
  daysInMonth: number
  firstDayCol: number  // 1-7 (Mon=1)
  cells: Array<{ day: number; amount: number; inRange: boolean }>
}

function startOfMonth(year: number, month: number): Date {
  return new Date(Date.UTC(year, month, 1))
}

function buildMonthGrids(rangeStart: string, rangeEnd: string, amountByISO: Map<string, number>): MonthGrid[] {
  const start = new Date(rangeStart)
  const end = new Date(rangeEnd)

  const grids: MonthGrid[] = []
  let cursor = startOfMonth(start.getUTCFullYear(), start.getUTCMonth())
  const lastMonth = startOfMonth(end.getUTCFullYear(), end.getUTCMonth())

  while (cursor.getTime() <= lastMonth.getTime()) {
    const year = cursor.getUTCFullYear()
    const month = cursor.getUTCMonth()
    const daysInMonth = new Date(Date.UTC(year, month + 1, 0)).getUTCDate()
    const firstDayOfMonth = new Date(Date.UTC(year, month, 1))
    const firstDayCol = ((firstDayOfMonth.getUTCDay() + 6) % 7) + 1  // Mon=1

    const cells: MonthGrid['cells'] = []
    for (let d = 1; d <= daysInMonth; d++) {
      const cellDate = new Date(Date.UTC(year, month, d))
      const inRange = cellDate.getTime() >= start.getTime() && cellDate.getTime() <= end.getTime()
      const iso = cellDate.toISOString().slice(0, 10)
      cells.push({ day: d, amount: amountByISO.get(iso) ?? 0, inRange })
    }

    grids.push({
      year,
      month,
      monthLabel: new Date(Date.UTC(year, month, 1)).toLocaleDateString('en', {
        month: 'long',
        year: 'numeric',
      }),
      daysInMonth,
      firstDayCol,
      cells,
    })

    cursor = startOfMonth(year, month + 1)
  }

  return grids
}

export function Heatmap({ data, rangeStart, rangeEnd, currency }: HeatmapProps) {
  const { grids, maxAmount } = useMemo(() => {
    const amountByISO = new Map<string, number>()
    for (const d of data) {
      const iso = new Date(d.date).toISOString().slice(0, 10)
      amountByISO.set(iso, parseFloat(d.amount))
    }
    const grids = buildMonthGrids(rangeStart, rangeEnd, amountByISO)
    const maxAmount = Math.max(0, ...Array.from(amountByISO.values()))
    return { grids, maxAmount }
  }, [data, rangeStart, rangeEnd])

  if (grids.length === 0) {
    return <p className="text-sm text-gray-400">No data.</p>
  }

  return (
    <div className="flex flex-col gap-4">
      {grids.map((grid) => (
        <div key={`${grid.year}-${grid.month}`}>
          <h3 className="text-[0.7rem] font-semibold text-gray-400 mb-1">{grid.monthLabel}</h3>
          <div className="grid grid-cols-7 gap-1 text-[0.65rem] text-gray-400 text-center mb-1">
            <div>Mon</div><div>Tue</div><div>Wed</div><div>Thu</div><div>Fri</div><div>Sat</div><div>Sun</div>
          </div>
          <div className="grid grid-cols-7 gap-1">
            {grid.cells.map((cell, i) => {
              if (!cell.inRange) {
                return (
                  <div
                    key={cell.day}
                    className="h-8 rounded-sm border border-base-100 bg-transparent"
                    style={{ gridColumnStart: i === 0 ? grid.firstDayCol : undefined }}
                  />
                )
              }
              const intensity = maxAmount > 0 ? cell.amount / maxAmount : 0
              const r = Math.round(254 + (220 - 254) * intensity)
              const g = Math.round(242 + (38 - 242) * intensity)
              const b = Math.round(242 + (38 - 242) * intensity)
              const bg = cell.amount > 0 ? `rgb(${r}, ${g}, ${b})` : 'transparent'
              return (
                <div
                  key={cell.day}
                  className="h-8 rounded-sm flex items-center justify-center text-[0.6rem] border border-base-100"
                  style={{
                    backgroundColor: bg,
                    color: intensity > 0.5 ? '#fff' : '#9CA3AF',
                    gridColumnStart: i === 0 ? grid.firstDayCol : undefined,
                  }}
                  title={cell.amount > 0 ? `${grid.monthLabel} ${cell.day}: ${formatMoney(cell.amount, currency)}` : `${grid.monthLabel} ${cell.day}`}
                >
                  {cell.day}
                </div>
              )
            })}
          </div>
        </div>
      ))}
    </div>
  )
}
```

- [ ] **Step 2: Type-check**

```bash
cd desktop/frontend && ./node_modules/.bin/tsc --noEmit
```
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/components/charts/Heatmap.tsx
git commit -m "feat(charts): add multi-month-aware Heatmap

Renders one calendar grid per month touched by the selected range,
stacked vertically. Days outside the range render as transparent
placeholders to preserve grid alignment. Replaces the inline
single-month heatmap that broke for ranges >30 days or crossing
month boundaries."
```

---

## Task 8: Frontend — create `Sparkline` component

**Files:**
- Create: `desktop/frontend/src/components/charts/Sparkline.tsx`

- [ ] **Step 1: Create the file**

```tsx
import { LineChart, Line, ResponsiveContainer } from 'recharts'
import type { AggregatedBar } from '../../utils/insightsBucket'

interface SparklineProps {
  bars: AggregatedBar[]
}

export function Sparkline({ bars }: SparklineProps) {
  if (bars.length === 0) {
    return <div className="h-[40px]" />
  }

  return (
    <ResponsiveContainer width="100%" height={40}>
      <LineChart data={bars} margin={{ top: 4, right: 4, left: 4, bottom: 4 }}>
        <Line
          type="monotone"
          dataKey="amount"
          stroke="#6B5CE7"
          strokeWidth={1.5}
          dot={false}
          isAnimationActive={false}
        />
      </LineChart>
    </ResponsiveContainer>
  )
}
```

- [ ] **Step 2: Type-check**

```bash
cd desktop/frontend && ./node_modules/.bin/tsc --noEmit
```
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/components/charts/Sparkline.tsx
git commit -m "feat(charts): add Sparkline for Overview at-a-glance trend"
```

---

## Task 9: Frontend — create `QuickStatsCard` component

**Files:**
- Create: `desktop/frontend/src/components/cards/QuickStatsCard.tsx`

- [ ] **Step 1: Create the directory and file**

```bash
mkdir -p desktop/frontend/src/components/cards
```

Create `desktop/frontend/src/components/cards/QuickStatsCard.tsx`:

```tsx
import { formatMoney } from '../../utils/money'
import type { QuickStats } from '../../types/api'

interface QuickStatsCardProps {
  stats: QuickStats
  currency: string
  caption?: string
}

export function QuickStatsCard({ stats, currency, caption }: QuickStatsCardProps) {
  const savingsRate = parseFloat(stats.savings_rate)
  const showSavingsRate = !isNaN(savingsRate) && savingsRate !== 0

  const cells: Array<{ label: string; value: string }> = [
    { label: 'Top Merchant', value: stats.top_merchant?.name || '—' },
    {
      label: 'Biggest Transaction',
      value: stats.biggest_transaction?.name
        ? `${stats.biggest_transaction.name} · ${formatMoney(stats.biggest_transaction.amount, currency)}`
        : '—',
    },
    { label: 'Average Transaction', value: formatMoney(stats.avg_transaction, currency) || '—' },
    { label: 'Transaction Count', value: String(stats.transaction_count ?? 0) },
  ]

  return (
    <div className="card bg-base-200 rounded-xl p-4 flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="text-[0.8rem] font-bold">Quick Stats</h2>
        {caption && <span className="text-[0.65rem] text-gray-400">{caption}</span>}
      </div>

      {showSavingsRate && (
        <div className="rounded-lg px-3 py-2 bg-base-100 border-l-4 border-[#10B981]">
          <div className="text-[0.65rem] uppercase tracking-wide text-gray-400">Savings Rate</div>
          <div className="text-[1rem] font-bold text-[#10B981]">{savingsRate.toFixed(1)}%</div>
        </div>
      )}

      <div className="grid grid-cols-2 gap-2">
        {cells.map((c) => (
          <div key={c.label} className="rounded-lg px-3 py-2 bg-base-100">
            <div className="text-[0.65rem] uppercase tracking-wide text-gray-400">{c.label}</div>
            <div className="text-[0.85rem] font-semibold truncate" title={c.value}>{c.value}</div>
          </div>
        ))}
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Type-check**

```bash
cd desktop/frontend && ./node_modules/.bin/tsc --noEmit
```
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/components/cards/QuickStatsCard.tsx
git commit -m "feat(cards): add QuickStatsCard surfacing existing API quick_stats

Renders top merchant, biggest transaction, average transaction, and
transaction count in a 4-up grid. Savings rate row is conditional on
non-zero savings (hidden when income is zero, per spec)."
```

---

## Task 10: Frontend — create `RecurringSection` component

**Files:**
- Create: `desktop/frontend/src/components/insights/RecurringSection.tsx`

- [ ] **Step 1: Create the directory and file**

```bash
mkdir -p desktop/frontend/src/components/insights
```

Create `desktop/frontend/src/components/insights/RecurringSection.tsx`:

```tsx
import { useRecurrenceTimeline } from '../../hooks/useRecurrenceTimeline'
import { formatMoney } from '../../utils/money'
import type { NextRecurringTransaction } from '../../types/api'

interface RecurringSectionProps {
  upcoming: NextRecurringTransaction[]
  currency: string
}

export function RecurringSection({ upcoming, currency }: RecurringSectionProps) {
  const { data: timeline, loading, error } = useRecurrenceTimeline()

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-2">
        <div className="flex-1 h-px bg-base-300" />
        <span className="text-[0.65rem] text-gray-400">Forward-looking · independent of selected range</span>
        <div className="flex-1 h-px bg-base-300" />
      </div>

      <div className="card bg-base-200 rounded-xl p-4">
        <h2 className="text-[0.8rem] font-bold mb-3">Next 30 Days Timeline</h2>
        {loading ? (
          <div className="skeleton h-20" />
        ) : error ? (
          <div className="alert alert-warning text-xs">Unable to load recurring transactions</div>
        ) : timeline.length === 0 ? (
          <p className="text-sm text-gray-400">No recurring transactions in the next 30 days.</p>
        ) : (
          <div className="relative h-32">
            {(() => {
              const today = new Date()
              const dayMs = 24 * 60 * 60 * 1000
              const labels = [0, 7, 14, 21, 30]
              return (
                <>
                  <div className="absolute bottom-0 left-0 right-0 flex text-[0.6rem] text-gray-400">
                    {labels.map((d) => (
                      <span key={d} className="absolute" style={{ left: `${(d / 30) * 100}%`, transform: 'translateX(-50%)' }}>
                        {d === 0 ? 'Today' : `+${d}d`}
                      </span>
                    ))}
                  </div>
                  <div className="absolute top-0 left-0 right-0 bottom-4">
                    {timeline.map((occ) => {
                      const date = new Date(occ.date)
                      const offsetDays = Math.max(0, Math.min(30, Math.round((date.getTime() - today.getTime()) / dayMs)))
                      const left = (offsetDays / 30) * 100
                      const isIncome = occ.type === 'income'
                      return (
                        <div
                          key={`${occ.id}-${occ.date}`}
                          className="absolute text-[0.65rem] px-1.5 py-0.5 rounded-md whitespace-nowrap transform -translate-x-1/2"
                          style={{
                            left: `${left}%`,
                            top: `${(occ.id % 3) * 24}px`,
                            backgroundColor: isIncome ? '#22C55E' : '#EF4444',
                            color: '#fff',
                          }}
                        >
                          {occ.name} {formatMoney(occ.amount, occ.currency)}
                        </div>
                      )
                    })}
                  </div>
                </>
              )
            })()}
          </div>
        )}
      </div>

      {upcoming.length > 0 && (
        <div className="card bg-base-200 rounded-xl p-4">
          <h2 className="text-[0.8rem] font-bold mb-3">Upcoming Recurring</h2>
          <ul className="flex flex-col gap-2">
            {upcoming.map((r, i) => (
              <li key={i} className="flex justify-between text-[0.8rem]">
                <span>{r.name}</span>
                <div className="text-right">
                  <div className="text-[#EF5350] font-semibold">{formatMoney(r.amount, currency)}</div>
                  <div className="text-[0.7rem] text-gray-400">{new Date(r.date).toLocaleDateString()}</div>
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}
```

- [ ] **Step 2: Type-check**

```bash
cd desktop/frontend && ./node_modules/.bin/tsc --noEmit
```
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/components/insights/RecurringSection.tsx
git commit -m "feat(insights): add RecurringSection decoupled from analysis range

Always renders 'next 30 days' timeline plus the upcoming list. Used
on both Overview and Analysis tabs to give a stable forward-looking
view independent of the user's analysis range selection."
```

---

## Task 11: Frontend — restructure `Insights.tsx` to use new components

**Files:**
- Modify: `desktop/frontend/src/pages/Insights.tsx` (full restructure)

- [ ] **Step 1: Read the current file in full to understand what's being replaced**

```bash
sed -n '1,460p' desktop/frontend/src/pages/Insights.tsx | wc -l
```
Expected: file is currently ~460 lines. The new version will be ~220 lines because chart bodies move to components.

- [ ] **Step 2: Replace `desktop/frontend/src/pages/Insights.tsx` with the new content**

Overwrite the entire file with:

```tsx
import { useMemo, useState, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { useInsights } from '../hooks/useInsights'
import { usePatterns } from '../hooks/usePatterns'
import { StatCard } from '../components/ui/StatCard'
import { DateRangeBar } from '../components/ui/DateRangeBar'
import { CategoryDonut, type DonutSlice } from '../components/charts/CategoryDonut'
import { CategoryComparisonBar, type ComparisonRow } from '../components/charts/CategoryComparisonBar'
import { TrendChart } from '../components/charts/TrendChart'
import { Heatmap } from '../components/charts/Heatmap'
import { Sparkline } from '../components/charts/Sparkline'
import { QuickStatsCard } from '../components/cards/QuickStatsCard'
import { RecurringSection } from '../components/insights/RecurringSection'
import { formatMoney } from '../utils/money'
import {
  formatDateRangeCaption,
  getPresetRange,
} from '../utils/dateRange'
import {
  getBucket,
  getAggregation,
  aggregateByPeriod,
  calculatePreviousPeriodAverage,
  getPreviousPeriodRange,
} from '../utils/insightsBucket'
import { createLogger } from '../utils/logger'

const logger = createLogger('InsightsPage')

interface InsightsProps {
  tab: 'overview' | 'analysis' | 'patterns'
}

const RANGE_STORAGE_KEY = 'moneef:insights-range'

function getInitialRange(): { start: string; end: string } {
  try {
    const raw = sessionStorage.getItem(RANGE_STORAGE_KEY)
    if (raw) {
      const parsed = JSON.parse(raw)
      if (parsed.start && parsed.end) return parsed
    }
  } catch { }
  const defaultRange = getPresetRange('this_month')
  return { start: defaultRange.startDateTime, end: defaultRange.endDateTime }
}

function getPatternPeriodDates(period: 'all' | '30d' | '90d' | '12m'): { startDate?: string; endDate?: string } {
  if (period === 'all') return {}
  const now = new Date()
  const end = now.toISOString()
  switch (period) {
    case '30d':
      return { startDate: new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString(), endDate: end }
    case '90d':
      return { startDate: new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000).toISOString(), endDate: end }
    case '12m':
      return { startDate: new Date(now.getFullYear() - 1, now.getMonth(), now.getDate()).toISOString(), endDate: end }
    default:
      return {}
  }
}

export function Insights({ tab }: InsightsProps) {
  const [range, setRange] = useState<{ start: string; end: string }>(getInitialRange)
  const { data, loading, error, refetch } = useInsights(range.start, range.end)
  const { data: patterns, loading: pLoading, error: pError, analyzing, analyzeNow } = usePatterns()
  const navigate = useNavigate()
  const [trendView, setTrendView] = useState<'chart' | 'heatmap'>('chart')
  const [patternPeriod, setPatternPeriod] = useState<'all' | '30d' | '90d' | '12m'>('all')

  const handleRangeChange = useCallback((start: string, end: string) => {
    const next = { start, end }
    setRange(next)
    sessionStorage.setItem(RANGE_STORAGE_KEY, JSON.stringify(next))
  }, [])

  logger.debug('Insights rendered', { tab, hasData: !!data, patternsCount: patterns.length })

  const charts = data?.AnalysisCharts
  const expense = parseFloat(charts?.total ?? '0')
  const net = -expense
  const currency = data?.currency || 'USD'

  const bucket = getBucket(range.start, range.end)
  const aggregation = getAggregation(range.start, range.end)
  const previousRange = useMemo(() => getPreviousPeriodRange(range.start, range.end), [range.start, range.end])
  const currentLabel = formatDateRangeCaption(range.start, range.end)
  const previousLabel = formatDateRangeCaption(previousRange.start, previousRange.end)

  const trendBars = useMemo(
    () => aggregateByPeriod(charts?.spent_per_day ?? [], aggregation),
    [charts, aggregation]
  )
  const previousAverage = useMemo(
    () => calculatePreviousPeriodAverage(charts?.spent_per_day_last_period ?? [], aggregation),
    [charts, aggregation]
  )

  const donutData: DonutSlice[] = useMemo(
    () =>
      (charts?.categories ?? []).map((c) => ({
        name: c.category_name,
        amount: parseFloat(c.total_amount),
        pct: parseFloat(c.percentage),
        color: c.color || '#9CA3AF',
      })),
    [charts]
  )

  const comparisonData: ComparisonRow[] = useMemo(() => {
    const map = new Map<string, ComparisonRow>()
    for (const c of charts?.categories ?? []) {
      map.set(c.category_name, { name: c.category_name, current: parseFloat(c.total_amount), previous: 0 })
    }
    for (const c of charts?.categories_last_period ?? []) {
      const existing = map.get(c.category_name) ?? { name: c.category_name, current: 0, previous: 0 }
      existing.previous = parseFloat(c.total_amount)
      map.set(c.category_name, existing)
    }
    return Array.from(map.values())
  }, [charts])

  const trendTitle =
    aggregation === 'daily' ? 'Daily Spending' :
    aggregation === 'weekly' ? 'Weekly Spending' :
    'Monthly Spending'

  if (loading) return <div className="skeleton h-96 rounded-xl" />

  if (error) {
    logger.warn('Insights error displayed:', error)
    return (
      <div className="alert alert-error flex flex-col items-start gap-2">
        <span className="font-semibold">Failed to load insights</span>
        <span className="text-sm opacity-90">{error}</span>
        <button className="btn btn-sm btn-ghost mt-1" onClick={refetch}>Retry</button>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-4">
      {/* Sub-tab bar */}
      <div className="tabs tabs-boxed w-fit">
        <button className={`tab ${tab === 'overview' ? 'tab-active' : ''}`} onClick={() => navigate('/insights')}>Overview</button>
        <button className={`tab ${tab === 'analysis' ? 'tab-active' : ''}`} onClick={() => navigate('/insights/analysis')}>Analysis</button>
        <button className={`tab ${tab === 'patterns' ? 'tab-active' : ''}`} onClick={() => navigate('/insights/patterns')}>Patterns</button>
      </div>

      {(tab === 'overview' || tab === 'analysis') && (
        <DateRangeBar startDate={range.start} endDate={range.end} onChange={handleRangeChange} />
      )}

      {tab === 'overview' && (
        <div className="flex flex-col gap-4">
          <div className="grid grid-cols-3 gap-4">
            <StatCard label={`Expenses · ${currentLabel}`} value={formatMoney(expense, currency)} borderColor="#EF5350" bgColor="bg-[#FDE8E8]" textColor="text-[#EF5350]" />
            <StatCard label={`Net · ${currentLabel}`} value={formatMoney(net, currency)} borderColor="#6B5CE7" />
            <StatCard label="Categories" value={`${donutData.length}`} borderColor="#26C6DA" />
          </div>

          <div className="card bg-base-200 rounded-xl p-4">
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-[0.8rem] font-bold">Spending by Category</h2>
              <button className="text-[0.65rem] text-primary underline" onClick={() => navigate('/insights/analysis')}>View all</button>
            </div>
            {donutData.length === 0 ? (
              <p className="text-sm text-gray-400">No data for this period.</p>
            ) : (
              <div className="flex flex-col gap-2">
                {donutData.slice(0, 5).map(c => (
                  <div key={c.name} className="flex items-center gap-3">
                    <span className="text-[0.75rem] w-28 truncate">{c.name}</span>
                    <div className="flex-1 bg-base-100 rounded-full h-2 overflow-hidden">
                      <div className="h-2 rounded-full" style={{ width: `${Math.min(c.pct, 100)}%`, backgroundColor: c.color }} />
                    </div>
                    <span className="text-[0.75rem] w-16 text-right">{formatMoney(c.amount, currency)}</span>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="card bg-base-200 rounded-xl p-4">
            <div className="flex items-center justify-between mb-2">
              <h2 className="text-[0.8rem] font-bold">{trendTitle}</h2>
              <span className="text-[0.65rem] text-gray-400">{currentLabel}</span>
            </div>
            <Sparkline bars={trendBars} />
          </div>

          <div className="card bg-base-200 rounded-xl p-4">
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-[0.8rem] font-bold">Spending Patterns</h2>
              <span className="text-[0.65rem] text-gray-400">from all-time history</span>
            </div>
            {pLoading ? (
              <div className="skeleton h-20" />
            ) : pError ? (
              <div className="alert alert-warning text-xs">Could not load patterns: {pError}</div>
            ) : patterns.length === 0 ? (
              <p className="text-sm text-gray-400">No patterns detected yet.</p>
            ) : (
              <ul className="flex flex-col gap-2">
                {patterns.slice(0, 3).map(p => (
                  <li key={p.ID} className="text-[0.8rem] flex gap-2 items-start">
                    <span style={{ color: p.color || '#6B5CE7' }}>{p.icon || '💡'}</span>
                    <span>{p.description}</span>
                  </li>
                ))}
              </ul>
            )}
          </div>

          <RecurringSection upcoming={charts?.next_recurring_transactions ?? []} currency={currency} />
        </div>
      )}

      {tab === 'analysis' && (
        <div className="flex flex-col gap-4">
          {charts?.quick_stats && (
            <QuickStatsCard stats={charts.quick_stats} currency={currency} caption={currentLabel} />
          )}

          <div className="card bg-base-200 rounded-xl p-4">
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-[0.8rem] font-bold">Spending by Category — Composition</h2>
              <span className="text-[0.65rem] text-gray-400">{currentLabel}</span>
            </div>
            <CategoryDonut data={donutData} total={expense} currency={currency} />
          </div>

          <div className="card bg-base-200 rounded-xl p-4">
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-[0.8rem] font-bold">Spending by Category — vs Previous Period</h2>
              <span className="text-[0.65rem] text-gray-400">{currentLabel} vs {previousLabel}</span>
            </div>
            <CategoryComparisonBar
              data={comparisonData}
              currency={currency}
              currentLabel={currentLabel}
              previousLabel={previousLabel}
            />
          </div>

          <div className="card bg-base-200 rounded-xl p-4">
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-[0.8rem] font-bold">{trendTitle}</h2>
              <div className="flex items-center gap-2">
                <span className="text-[0.65rem] text-gray-400">{currentLabel}</span>
                {bucket === 'short' && (
                  <div className="tabs tabs-xs tabs-boxed">
                    <button className={`tab ${trendView === 'chart' ? 'tab-active' : ''}`} onClick={() => setTrendView('chart')}>Chart</button>
                    <button className={`tab ${trendView === 'heatmap' ? 'tab-active' : ''}`} onClick={() => setTrendView('heatmap')}>Heatmap</button>
                  </div>
                )}
              </div>
            </div>
            {bucket === 'short' && trendView === 'heatmap' ? (
              <Heatmap data={charts?.spent_per_day ?? []} rangeStart={range.start} rangeEnd={range.end} currency={currency} />
            ) : (
              <TrendChart
                bars={trendBars}
                currency={currency}
                previousAverage={previousAverage}
                previousAverageLabel={`Avg of previous period (${previousLabel})`}
              />
            )}
          </div>

          <RecurringSection upcoming={charts?.next_recurring_transactions ?? []} currency={currency} />
        </div>
      )}

      {tab === 'patterns' && (
        <div className="flex flex-col gap-4">
          <div className="grid grid-cols-2 gap-4">
            <StatCard label="Patterns Found" value={`${patterns.length}`} borderColor="#6B5CE7" />
            <StatCard label="Top Score" value={patterns[0] ? `${patterns[0].final_score.toFixed(0)}%` : '—'} borderColor="#26C6DA" />
          </div>
          <div className="card bg-base-200 rounded-xl p-4">
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-[0.8rem] font-bold">Spending Pattern Insights</h2>
              <div className="flex items-center gap-2">
                <div className="tabs tabs-xs tabs-boxed">
                  <button className={`tab ${patternPeriod === 'all' ? 'tab-active' : ''}`} onClick={() => { setPatternPeriod('all'); analyzeNow() }}>All time</button>
                  <button className={`tab ${patternPeriod === '30d' ? 'tab-active' : ''}`} onClick={() => { setPatternPeriod('30d'); analyzeNow(getPatternPeriodDates('30d')) }}>Last 30 days</button>
                  <button className={`tab ${patternPeriod === '90d' ? 'tab-active' : ''}`} onClick={() => { setPatternPeriod('90d'); analyzeNow(getPatternPeriodDates('90d')) }}>Last 90 days</button>
                  <button className={`tab ${patternPeriod === '12m' ? 'tab-active' : ''}`} onClick={() => { setPatternPeriod('12m'); analyzeNow(getPatternPeriodDates('12m')) }}>Last 12 months</button>
                </div>
                <button
                  className="btn btn-primary btn-sm"
                  disabled={analyzing}
                  onClick={() => analyzeNow(getPatternPeriodDates(patternPeriod))}
                >
                  {analyzing ? <span className="loading loading-spinner loading-xs" /> : 'Analyze Now'}
                </button>
              </div>
            </div>
            {pLoading ? (
              <div className="skeleton h-32" />
            ) : pError ? (
              <div className="alert alert-warning text-xs">Could not load patterns: {pError}</div>
            ) : patterns.length === 0 ? (
              <p className="text-sm text-gray-400">No patterns detected. Add more transactions to build history.</p>
            ) : (
              <ul className="flex flex-col gap-3">
                {patterns.map(p => (
                  <li key={p.ID} className="flex gap-3 items-start border-b border-base-100 pb-3 last:border-0">
                    <span className="text-lg" style={{ color: p.color || '#6B5CE7' }}>{p.icon || '💡'}</span>
                    <div>
                      <div className="text-[0.8rem] font-medium">{p.description}</div>
                      <div className="text-[0.7rem] text-gray-400 mt-0.5">
                        Score: {p.final_score.toFixed(0)}% · {p.pattern_type} · {new Date(p.CreatedAt).toLocaleDateString()}
                      </div>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
```

- [ ] **Step 3: Type-check**

```bash
cd desktop/frontend && ./node_modules/.bin/tsc --noEmit
```
Expected: no output, exit 0.

- [ ] **Step 4: Production build**

```bash
cd desktop/frontend && npm run build
```
Expected: `vite build` completes successfully. The chunk-size warning is pre-existing and acceptable.

- [ ] **Step 5: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/pages/Insights.tsx
git commit -m "refactor(insights): restructure page into lean Overview + deep Analysis

Wires the new chart components and bucketing util together. Overview
now shows stat cards + top-5 categories + sparkline + top patterns.
Analysis shows quick stats + donut + comparison bar + trend chart
(with heatmap toggle for short ranges only). Recurring section is
decoupled and rendered at the bottom of both tabs. Radar chart and
the misleading dual-line cumulative chart are removed."
```

---

## Task 12: Manual verification matrix

**Files:** none modified. This task is verification only.

- [ ] **Step 1: Start the dev server**

```bash
cd desktop/frontend && npm run dev
```
Open the resulting URL in the browser. Login if needed.

- [ ] **Step 2: For each row in this matrix, navigate to Insights, set the range, and verify**

| # | Range preset | Expected bucket | Verify on Overview | Verify on Analysis |
|---|---|---|---|---|
| 1 | This Month | short | Sparkline non-empty; stat cards labeled with range | Donut + bar + trend; heatmap toggle visible |
| 2 | Last 30 Days | short | Same | Heatmap toggle present; switching to heatmap shows up to 2 stacked monthly grids |
| 3 | Last 3 Months | long | Sparkline still works | Trend title = "Weekly Spending"; heatmap toggle absent |
| 4 | This Year | long-weekly | OK | Weekly trend; reasonable bar count |
| 5 | All Time | long-monthly | OK | Trend title = "Monthly Spending" |
| 6 | Custom range crossing year boundary | long-{auto} | OK | Aggregation chosen correctly; labels format correctly |

For each row, additionally verify:

- The "vs Previous Period" bar legend shows two literal date ranges, not the words "This/Last period"
- The Recurring section appears at the bottom and shows the same content regardless of which range row is being tested
- The Quick Stats card shows the savings rate row only when income exists in the range; with an expense-only range it should be hidden
- The dotted previous-period average line appears on the trend chart when `previousAverage > 0`

- [ ] **Step 3: Confirm no regressions on the Patterns tab**

Click Patterns tab. Confirm:
- "All time", "Last 30 days", "Last 90 days", "Last 12 months" preset buttons still work
- "Analyze Now" button still triggers analysis
- Existing patterns still render with icons + colors

- [ ] **Step 4: If everything checks out, mark complete**

No commit at this step (verification only). If issues are found, file fixes as additional tasks before declaring done.

---

## Self-review

### Spec coverage check

| Spec section | Covered by task |
|---|---|
| Bucketing rules | Task 3 (`getBucket`, `getAggregation`) |
| Comparison rule | Tasks 5, 6, 11 (literal labels everywhere) |
| Spending Trend chart | Task 6 (`TrendChart`) + Task 11 (wiring + dynamic title) |
| Heatmap (short bucket only, multi-month) | Task 7 (`Heatmap`) + Task 11 (toggle gated on `bucket === 'short'`) |
| Spending by Category — Composition | Task 4 (`CategoryDonut`) + Task 11 |
| Spending by Category — vs Previous Period | Task 5 (`CategoryComparisonBar`) + Task 11 |
| Quick Stats card | Task 9 (`QuickStatsCard`) + Task 11; savings-rate hide condition implemented |
| Sparkline on Overview | Task 8 (`Sparkline`) + Task 11 |
| Recurring decoupled | Task 1 (backend window) + Task 10 (`RecurringSection`) + Task 11 (placement on both tabs) |
| Overview lean layout | Task 11 (overview branch of `Insights.tsx`) |
| Analysis deep layout | Task 11 (analysis branch of `Insights.tsx`) |
| Type fix for `quick_stats` | Task 2 |
| Backend recurrence window change | Task 1 |
| Radar removal | Task 11 (omitted from new file) |
| Manual verification matrix | Task 12 |

No gaps.

### Placeholder scan

No "TBD" or "TODO" markers. All code blocks are complete and self-contained.

### Type/identifier consistency

- `AggregatedBar` defined in Task 3 (`insightsBucket.ts`); imported by Tasks 6, 8, 11. ✓
- `DonutSlice`, `ComparisonRow` defined in Tasks 4 and 5; imported by Task 11. ✓
- `QuickStats` defined in Task 2 (types); imported by Tasks 9 and 11. ✓
- `getBucket`, `getAggregation`, `aggregateByPeriod`, `calculatePreviousPeriodAverage`, `getPreviousPeriodRange` defined in Task 3; all used in Task 11. ✓
- `formatDateRangeCaption`, `getPresetRange` already exist in `utils/dateRange.ts` (verified in spec). ✓
- `useRecurrenceTimeline` already exists; consumed in Task 10. ✓
- Backend test in Task 1 imports `MoneyFromFloat` and `testProfileID` from existing `tests/test_utils.go` (per existing test conventions). ✓

No inconsistencies.
