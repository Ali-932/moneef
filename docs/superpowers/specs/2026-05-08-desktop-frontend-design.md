# Moneef Desktop Frontend — Design Spec

**Date:** 2026-05-08
**Status:** Approved

---

## Overview

Moneef is a personal finance desktop application built with Wails v2. The frontend is a React + TypeScript app served from an embedded Go HTTP server on `localhost:7331`. This spec defines the visual design system, layout architecture, page structure, and component decisions for the desktop frontend.

The design adapts the original mobile concept to a native desktop experience — preserving the soft purple vibe while replacing stretched mobile patterns with information-dense, multi-column desktop layouts.

---

## Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| UI framework | React + TypeScript | Already in place |
| Styling | Tailwind CSS + DaisyUI | Theming, dark mode, all needed components out of the box |
| Charts | Recharts | React-native, easy to style with design tokens |
| Routing | React Router DOM | SPA navigation between pages |
| Build | Vite (existing) | Already configured |

**New dependencies to add:**
```
tailwindcss @tailwindcss/vite daisyui recharts react-router-dom
```

---

## Design Tokens

### Colors

| Token | Value | Usage |
|---|---|---|
| `primary` | `#6B5CE7` | Sidebar, active states, buttons, accents |
| `primary-light` | `#A89EF0` | Chart bars (secondary), hover states |
| `base-100` | `#F7F6FB` | App background |
| `base-200` | `#FFFFFF` | Card / panel backgrounds |
| `income-bg` | `#E8F5E8` | Income stat card background |
| `income-text` | `#2D7A2D` | Income values and labels |
| `expense-bg` | `#FDE8E8` | Expense stat card background |
| `expense-text` | `#EF5350` | Expense values and labels |
| `net-accent` | `#6B5CE7` | Net balance left border |
| `avg-accent` | `#26C6DA` | Avg/day left border |

### Dark Mode Tokens

| Token | Value |
|---|---|
| `dark-base` | `#1E1B3A` |
| `dark-card` | `#2A2650` |
| `dark-sidebar` | `#15122E` |

Dark mode is toggled via DaisyUI's `data-theme` attribute on `<html>`. The active theme is persisted in `localStorage`.

### Typography

All sizes in `rem` relative to a root font size of `16px` (Wails webview default). These scale correctly at HiDPI/4K without change.

- Font: system-ui / `-apple-system` / `Segoe UI` stack (no custom font needed)
- Page titles: `0.9rem` (`font-weight: 700`)
- Section headers: `0.8rem` (`font-weight: 700`)
- Body / table rows: `0.8rem` (`font-weight: 400–600`)
- Stat card values: `1.125rem` bold
- Labels / timestamps: `0.7rem`, `color: #BBB`

### Border Radius

- Cards / panels: `rounded-xl` (10–12px)
- Stat mini cards: `rounded-xl`
- Buttons: `rounded-lg`
- Category badges: `rounded` (4px)
- Sidebar nav items: `rounded-lg`

---

## Layout Architecture

### Shell

```
┌─────────────────────────────────────────────────┐
│  Sidebar (210px fixed)  │  Main area (flex:1)   │
│                         │  ┌─ Top bar (48px) ─┐ │
│  Logo                   │  │ Page title  Ctrl  │ │
│  ─────────────          │  └───────────────────┘ │
│  Home (active)          │  ┌─ Content (scroll) ┐ │
│  Insights               │  │                   │ │
│  Transactions           │  │                   │ │
│  Profile                │  │                   │ │
│                         │  │                   │ │
│  [+ Add Transaction]    │  └───────────────────┘ │
└─────────────────────────────────────────────────┘
```

**Sidebar:**
- Fixed width: 210px
- Background: `#6B5CE7`
- Nav items: icon (16px) + label, `rounded-lg` hover/active
- Active state: `rgba(255,255,255,0.18)` background, white text
- Bottom: full-width white "＋ Add Transaction" button, `color: primary`

**Top bar:**
- Height: 48px, white background, `border-bottom: 1px solid #EBEBEB`
- Left: current page title
- Right: period/date picker + avatar

---

## Pages

### 1. Home (Dashboard)

**Layout:** Single scrollable column with sections.

**Sections (top to bottom):**

1. **Stat strip** — 4 compact cards in a `grid-cols-4` row:
   - Income (green left border, `#E8F5E8` background)
   - Expenses (red left border, `#FDE8E8` background)
   - Net (purple left border, white background)
   - Avg/Day (cyan left border, white background)
   - Each card: label (10px uppercase), large value (18px bold), sub-text with % change

2. **Notification bar** — single-line scrolling strip (`#F0EEF9` background, purple text) for upcoming recurring payments and alerts

3. **Two-column row** (`grid-cols-[1fr_340px]`):
   - **Left panel:** Weekly bar chart (Recharts `BarChart`) + spending category donut chart (`PieChart` with inner radius)
   - **Right panel:** Recent transactions as a compact table — columns: icon, merchant + timestamp, category badge, amount

4. **Three-column bottom row:**
   - Spending Patterns (AI insight cards)
   - Upcoming Recurring (next 2–3 items)
   - Budget Health (progress bars per category)

---

### 2. Transactions

**Layout:** Full-width content area.

**Sections:**

1. **Toolbar row:** search input (left) + date range picker + filter button (right)
2. **Category pill strip:** `Recent · Food · Entertainment · Shopping · Bills · ...` — horizontally scrollable `overflow-x-auto` container of `btn btn-sm` pill buttons; active pill uses `btn-primary`, inactive uses `btn-ghost`. Not DaisyUI `tabs` (which doesn't support overflow scroll).
3. **Transaction table** grouped by date:
   - Section header per date group: date label (bold) + daily net (green/red)
   - Table columns: icon, merchant name + time, category badge, amount
   - Row hover: subtle `#F7F6FB` background
4. **Recurring Transactions section** at bottom:
   - Sub-header: "Recurring Transactions" + "View All" link
   - Same table layout with colored icon squares and "Next payment" dates

---

### 3. Insights

**Layout:** Full-width with a sticky sub-tab bar below the top bar.

**Period selector** (top bar controls): `◀ Week 1 ▶` + `Weeks ▾` dropdown + mini calendar strip showing current period dates.

**Sub-tabs:** `Overview · Analysis · Patterns`

**Overview tab:**
- Income / Expenses / Net summary row (same stat strip style)
- Donut chart (spending by category) with legend
- Spending Patterns list (insight cards)

**Analysis tab:**
- Spending by Category: donut + radar chart side by side
- Spending Trends vs Last Period: grouped bar chart
- Cumulative spending: line chart (this period vs last)
- Calendar Heatmap: spending intensity per day
- Recurring this month: timeline/gantt-style strip

**Patterns tab:**
- Summary cards: total patterns score + vs last period %
- Spending pattern insight list (icon + text + timestamp)

---

### 4. Add Transaction (Modal)

Opens as a DaisyUI `modal` centered on screen (not a page navigation).

**Structure:**
- **Tabs:** Expense | Income (toggle at top)
- **Form fields:**
  - Transaction name (text input)
  - Amount + currency selector (inline)
  - Date picker
  - Category (single or multi — "Multiple" mode splits into category rows with amounts)
  - "+ Add Category" dashed button for splits
  - Merchant name
- **Recurring section:**
  - "Is Recurrent?" toggle
  - If on: Frequency dropdown (Weekly / Bi-Weekly / Monthly)
  - "Has end date?" toggle → End Date + Total Amount fields
  - Amount paid previously field

---

### 5. Profile

**Layout:** Single column, max-width `640px`, centered.

**Sections:**

1. **User card:** avatar circle, name, email, joined date, sync status badge
2. **Financial Setup:**
   - Categories → navigates to category management
   - Recurring Transactions → navigates to recurring management
3. **Preferences:**
   - Currency (select)
   - Locale (select)
   - Notifications (DaisyUI toggle)
   - Budget Limits (link)
   - Dark Mode (DaisyUI toggle → writes `data-theme` to `<html>`)

---

## Component Library Usage (DaisyUI)

| Component | Used For |
|---|---|
| `btn` | Add Transaction, filters, period picker |
| `card` | Stat cards, panel wrappers |
| `modal` | Add Transaction dialog |
| `toggle` | Dark mode, Notifications, Is Recurrent, Has end date |
| `tabs` | Insights sub-tabs (fixed 3 tabs), Expense/Income toggle in modal |
| `btn btn-sm` pill strip | Category filter row in Transactions (open-ended, scrollable) |
| `badge` | Category labels on transaction rows |
| `input`, `select` | All form fields in Add Transaction and Profile |
| `menu` | Sidebar navigation items |
| `avatar` | User profile card and top bar |

---

## Data Fetching Pattern

Each page fetches its own data via custom hooks wrapping the existing `apiFetch` utility. No external query library is added.

**Pattern for each data hook:**
```ts
function useDashboard() {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [retryCount, setRetryCount] = useState(0)

  useEffect(() => {
    setLoading(true)
    setError(null)
    apiFetch('/api/v1/dashboard/summary')
      .then(r => r.json()).then(setData)
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [retryCount])

  const refetch = () => setRetryCount(c => c + 1)
  return { data, loading, error, refetch }
}
```

**Hooks to create:**

| Hook | Endpoint |
|---|---|
| `useDashboard` | `GET /api/v1/dashboard/summary` (existing endpoint) |
| `useTransactions` | `GET /api/v1/transactions` |
| `useInsights` | `GET /api/v1/analysis/dashboard` |
| `usePatterns` | `GET /api/v1/analysis/patterns` |
| `useProfile` | `GET /api/v1/users/profile` + `GET /api/v1/users/settings` |

All hooks live in `src/hooks/`.

---

## Loading and Error States

**Loading:** Use DaisyUI `skeleton` blocks sized to match the component being loaded (e.g. 4 skeleton bars for the stat strip, a skeleton block for charts). Every async component renders skeletons while `loading === true`.

**Errors:** Use a DaisyUI `alert alert-error` banner displayed inside the relevant panel (not full-screen). Includes a "Retry" button that calls the hook's `refetch()` function.

**Empty states:** If data returns successfully but empty (e.g. no transactions), show a simple centered message with an icon and a call-to-action (e.g. "No transactions yet — add one").

---

## Authentication

Auth is handled outside this frontend. The JWT is assumed to be present in `localStorage` under the key `jwt` when the app loads (set by a login flow that may be added later or handled at the backend/Wails startup level).

The `apiFetch` utility already reads this token and attaches it as a `Bearer` header. If an API call returns `401`, the frontend clears `localStorage` and redirects to `/login`. A `Login` page is not in scope for this spec but its route (`/login`) is reserved.

---

## Routing Structure

```
/                  → Home (Dashboard)
/transactions      → Transactions
/insights          → Insights (default: Overview tab)
/insights/analysis → Insights Analysis tab
/insights/patterns → Insights Patterns tab
/profile           → Profile
```

Add Transaction is a modal overlay, not a route.

---

## Dark Mode

DaisyUI themes defined in `tailwind.config`:
- `moneef-light` — default
- `moneef-dark` — dark variant

On app load, read `localStorage.getItem('theme')` and apply `document.documentElement.setAttribute('data-theme', theme)`. The Profile page dark mode toggle writes back to localStorage and re-applies.

---

## File Structure

```
desktop/frontend/src/
  components/
    layout/
      Sidebar.tsx
      TopBar.tsx
      AppShell.tsx
    ui/
      StatCard.tsx
      TransactionTable.tsx
      CategoryBadge.tsx
      NotifBar.tsx
  pages/
    Home.tsx
    Transactions.tsx
    Insights.tsx
    Profile.tsx
  modals/
    AddTransactionModal.tsx
  services/
    api.ts          (existing)
  hooks/
    useTheme.ts
    useDashboard.ts
    useTransactions.ts
    useInsights.ts
    usePatterns.ts
    useProfile.ts
  App.tsx
  main.tsx
```
