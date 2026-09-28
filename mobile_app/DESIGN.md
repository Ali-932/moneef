---
name: Moneef Mobile
description: Personal finance with clear numbers, useful charts, and quiet controls.
colors:
  accent-text-light: "#6250D5"
  accent-text-dark: "#9B8DF1"
  accent-fill: "#6C5CE7"
  accent-soft-light: "#EDE9FE"
  surface-light: "#F6F6FA"
  card-light: "#FFFFFF"
  ink-light: "#252336"
  muted-light: "#5B6573"
typography:
  family: Manrope
  page-title: "26px / 800"
  main-amount: "36–38px / 800"
  section-title: "15px / 700"
  transaction: "14px / 600"
  supporting: "11–13px / 400–600"
rounded:
  small: "8px"
  medium: "12px"
  large: "16px"
spacing:
  screen: "20px"
  section: "20–24px"
  card: "16–18px"
---

# Moneef mobile design

The primary task is to understand the current period and record a transaction.
The interface gives amounts more weight than controls. Violet identifies actions
and selection. Income uses green; normal spending amounts use the text color.
Destructive actions retain rose.

## App identity and startup

The installed app is named Moneef. Its mark is the approved Fold M in white
on violet `#6C5CE7`, with a 24% corner radius. The source is
`assets/branding/moneef-icon.svg`. Run `python3 tool/generate_branding.py`
to regenerate the Flutter painter, Android vector resources, adaptive icons,
and PNG exports. `--check` verifies they match the source. The generator uses
the local `rsvg-convert` command and does not access the network.

The native Android launch screen shows the mark immediately. Flutter then shows
the same logo, the Manrope wordmark, and a slim indeterminate loading track while
the local database opens and the icon dictionary is prepared. The splash has
no artificial minimum duration. It fades into the welcome screen or saved
profile when initialization completes. Reduced motion stops the loading track
and removes the transition. Light and dark surfaces follow the app palette.

Launcher icons include legacy density PNGs, adaptive foreground/background
layers, and an Android 13 monochrome layer. Android launchers select the mask
for adaptive icons; the rounded shape is retained in the splash and PNGs.
Native resources follow the [Flutter launch-screen setup](https://docs.flutter.dev/platform-integration/android/splash-screen)
and [Android adaptive-icon specifications](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive).

## Typography and spacing

Manrope is bundled in `assets/fonts/Manrope.ttf` with its SIL Open Font License.
The app does not fetch fonts at runtime. The variable font provides weights
400 through 800. Financial figures use tabular digits where alignment matters.

Primary screens use a left-aligned title and a short subtitle. Detail pages use
a compact app bar with a back button. Screen margins are 20 logical pixels;
transaction list rows use 16 pixels. Rows grow with text size. At larger text
sizes, transaction amounts move beneath their names.

## Color and surfaces

`AppColors` in `lib/theme.dart` defines both themes. The light palette uses white
cards on a violet-tinted neutral surface. The dark palette uses three distinct
near-black surfaces. Cards use a 16-pixel radius, without decorative shadows.

Accent text has separate light and dark values. Filled actions use `accentFill`
with white text in both themes. Selected segments use a white or dark card
surface with violet text. Text and primary-action contrast are checked by
`test/widgets/design_review_test.dart`.

`QuietIcon` presents backend category colors as lightly tinted tiles with a
contrasting glyph. Charts keep the backend category colors so categories remain
recognizable across screens. Category names and percentages accompany colors.

## Screen structure

### Home

The overview starts with net cash flow for the selected period. Net cash flow
is income minus expenses; it is not an account balance. Two bars compare income
and expenses against the same maximum. Their exact amounts remain visible.
The share of income spent is shown only when income is positive.

The top spending category uses the dashboard's aggregate and a ring showing its
share of total expenses. Recent activity previews five transactions with a link
to the full list. Quick statistics and upcoming payments follow.

### Activity

Search, date selection, and filters precede date-grouped transactions. Each row
shows a category icon, transaction name, category and date or time, and signed
amount. Multiple category splits show a count beside the first category.
Category badges do not compete with names for horizontal space.

### Insights

The category donut shows up to five categories plus Other when more than six
categories exist. Other is the sum of the remaining categories. Selecting a
slice or legend row displays its actual amount and share of the period total.
Selecting the same category again restores the total.

The spending trend has a zero baseline, reference lines, a peak annotation,
and straight segments to avoid suggesting negative spending between points.
Analysis statistics use a shared panel with dividers. Pattern rows show a
readable description and a labeled score meter; tapping a row opens its details.

### Transactions and settings

The transaction form shows a calculated total, then the name, date, currency,
and category amounts. Category and amount fields align. Editing an amount
updates the total immediately and marks the form as changed.

Transaction details present a receipt summary, metadata, notes, and category
allocation bars. The profile screen shows a compact identity row. Its edit
button reveals the name fields inline. Settings, categories, currencies, and
recurring payments keep the same control and icon styles.

Discard confirmation uses a 24-pixel radius and inset, a Manrope heading, and
full-width actions. It emphasizes Keep editing; the discard
action uses rose text. Calendars use a violet-tinted header, rounded day
selections, and a filled confirmation button. Date ranges share these tokens.
Calendar grid labels adapt to narrow screens at large text settings; headers,
date entry fields, and actions retain the larger text size.

## Navigation and motion

The bottom bar has Home, Insights, Activity, and Profile destinations. A
48-pixel add button sits inside the bar. Content ends above the navigation bar,
so the add action never floats over a list row.

Tab highlights, category selections, changing totals, and the profile editor
animate over 200–250 milliseconds. Page transitions take 240 milliseconds.
List entrances finish within 240 milliseconds. Motion uses eased curves without
bounce. Reduced-motion settings disable movement or substitute a crossfade.

## Verification

`tool/design_review.sh` runs static analysis, widget tests, and screenshot
renders. Screenshots use the real theme, bundled font, widgets, and routes with
a fixture-backed native API. Layout overflow remains a test failure.

The review covers both themes, empty states, recurrence controls, 130% text,
narrow-phone scrolling, chart selection, profile editing, live amount updates,
and navigation at up to 200% text. Screenshot output is in
`test/screenshots/goldens`. `tool/design_gallery.py` builds a local comparison
with a supplied earlier screenshot directory.
