# Product

## Register

product

## Users

People tracking their own personal finances on a phone — logging income and
expenses, checking where money went this month, and watching upcoming recurring
payments. They are not accountants; they open the app in short, frequent bursts
(at the till, on the couch, mid-commute), often one-handed, and want an answer
fast: *am I okay this month?* The app runs the Moneef Go core in-process, so
data and concepts match the backend exactly.

## Product Purpose

Moneef Mobile lets a person record and understand their spending without
friction. Core jobs: add a transaction (with multiple category splits, optional
merchant/notes, and recurrence), browse and filter transaction history, read
insights (spending by category, trends, detected patterns), and manage profile,
currencies, and recurring templates. Success is a user who trusts the numbers,
logs spending consistently because it's quick, and leaves the app calmer than
they opened it — clear on their position, not alarmed by it.

The app covers the full Go core surface while keeping mobile-native
interactions (bottom sheets, pickers, infinite scroll, pull-to-refresh,
haptics). The Go backend is the source of truth, reached
through a native bridge; the app does not reinvent business logic.

## Brand Personality

**Calm, trustworthy, precise.** Money is stressful; the interface lowers the
temperature instead of raising it. Voice is plain and direct — no hype, no
exclamation, no gamified streaks or confetti. Numbers are the loudest thing on
screen; chrome stays quiet. Polish exists (haptics, skeletons, staggered
reveals, cross-fades) but always in service of calm and clarity, never as
spectacle — motion is short, eased-out, and never bounces. The feeling on
close should be *reassured and in control*.

## Anti-references

- **Generic bank app** — corporate navy/teal, sterile, form-dense enterprise
  banking UI. Moneef is warmer and lighter than that.
- **Crypto / neon dashboard** — dark glowing gradients, hype tickers, big
  pulsing numbers, gambling-app energy. The opposite of calm.
- **Cluttered spreadsheet** — everything visible at once, tables with no
  hierarchy, dense grids. Mobile demands one clear answer per screen.
- **Generic AI/SaaS slop** — cream/sand backgrounds, tracked-uppercase eyebrows
  over every section, identical icon-card grids, gradient text. Banned on sight.

## Design Principles

1. **Information first.** Show the number and the answer; decoration earns its
   place or it's cut.
2. **Calm over clever.** Reduce money anxiety. Subtle motion, generous
   breathing room, no alarm-red unless something is actually wrong.
3. **Mobile-native, not a shrunk desktop.** Thumb-reachable actions, bottom
   sheets over modals, pull-to-refresh, pickers, haptics on real state changes.
4. **Motion serves meaning.** Every animation clarifies a change or a hierarchy;
   none exists for flourish. Always degrades under reduced motion.
5. **One source of truth.** Backend owns the logic; the UI presents it honestly,
   including empty and error states, never fakes or hides data.

## Accessibility & Inclusion

Target **WCAG 2.1 AA**: body text ≥4.5:1 and large/bold text ≥3:1 against its
background — watch the muted grays (`AppColors.muted` on tinted card
backgrounds) and income/expense accent text on their tinted fills. Every
animation already honors `MediaQuery.disableAnimations` / reduced-motion and
must continue to. Don't encode meaning in color alone (income vs expense also
carries sign and label, not just green/red). Respect OS text scaling; test
forms and number-heavy rows at larger type sizes.
