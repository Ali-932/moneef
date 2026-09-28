# Moneef Mobile API Reference

The `mobilebridge/` package is the gomobile-bound entry point for the Moneef Go
core when embedded in a Flutter Android app via a Kotlin `MethodChannel`.

This document is the **single source of truth** for every call available to
the Flutter layer: signatures, request/response JSON schemas, errors,
Kotlin invocation, and Dart caller.

> **REST analog.** Each entry in this doc is the in-process equivalent of an
> HTTP endpoint served by `cmd/api` (routes in `internal/routes/`). The body of a `POST` request
> becomes the `payload []byte` argument; the JSON response body becomes the
> returned `[]byte`. URL path params become `int64` arguments. Query params
> become fields inside the JSON request payload.

---

## Table of contents

- [Conventions](#conventions)
  - [Marshaling primitives across JNI](#marshaling-primitives-across-jni)
  - [Money serialization (decimal-as-string)](#money-serialization-decimal-as-string)
  - [Date / time format](#date--time-format)
  - [Identifiers](#identifiers)
  - [Error model](#error-model)
- [Lifecycle](#lifecycle)
  - [State machine](#state-machine)
  - [First-run vs returning-user paths](#first-run-vs-returning-user-paths)
- [Lifecycle endpoints](#lifecycle-endpoints)
  - [`Init(dbPath, profileID) error`](#initdbpath-profileid-error)
  - [`SetProfileID(id) error`](#setprofileidid-error)
  - [`Shutdown() error`](#shutdown-error)
- [Setup](#setup)
  - [`Setup(payload) → []byte`](#setuppayload---byte)
- [Transactions](#transactions)
  - [`CreateTransaction(payload) → []byte`](#createtransactionpayload---byte)
  - [`ListTransactions(payload) → []byte`](#listtransactionspayload---byte)
  - [`GetTransaction(id) → []byte`](#gettransactionid---byte)
  - [`UpdateTransaction(id, payload) → []byte`](#updatetransactionid-payload---byte)
  - [`DeleteTransaction(id) error`](#deletetransactionid-error)
- [Recurrences](#recurrences)
  - [`ListRecurrences() → []byte`](#listrecurrences---byte)
  - [`RecurrenceTimeline() → []byte`](#recurrencetimeline---byte)
  - [`DeleteRecurrence(id) error`](#deleterecurrenceid-error)
- [Categories](#categories)
  - [`ListCategories(payload) → []byte`](#listcategoriespayload---byte)
  - [`CreateCategory(payload) → []byte`](#createcategorypayload---byte)
  - [`UpdateCategory(id, payload) error`](#updatecategoryid-payload-error)
  - [`DeleteCategory(id) error`](#deletecategoryid-error)
- [Dashboard](#dashboard)
  - [`Dashboard(payload) → []byte`](#dashboardpayload---byte)
- [Analysis](#analysis)
  - [`Analysis(payload) → []byte`](#analysispayload---byte)
- [Patterns](#patterns)
  - [Pattern detection model](#pattern-detection-model)
  - [Pattern type catalog](#pattern-type-catalog)
  - [`Patterns() → []byte`](#patterns---byte)
  - [`RefreshPatterns(payload) → []byte`](#refreshpatternspayload---byte)
- [Profile & settings](#profile--settings)
  - [`GetProfile() → []byte`](#getprofile---byte)
  - [`UpdateProfile(payload) error`](#updateprofilepayload-error)
  - [`GetSettings() → []byte`](#getsettings---byte)
  - [`UpdateSettings(payload) error`](#updatesettingspayload-error)
- [Currencies & exchange rates](#currencies--exchange-rates)
  - [`ListCurrencies() → []byte`](#listcurrencies---byte)
  - [`ListExchangeRates(payload) → []byte`](#listexchangeratespayload---byte)
  - [`UpsertExchangeRate(payload) error`](#upsertexchangeratepayload-error)
  - [`FetchExchangeRates() error`](#fetchexchangerates-error)
- [Building the AAR](#building-the-aar)
- [Local backup functions](#local-backup-functions)
- [Out-of-process smoke test](#out-of-process-smoke-test)

---

## Conventions

### Marshaling primitives across JNI

gomobile bind can cross the JNI boundary with **only** these Go types:
`string`, `[]byte`, `int64`, `error`, `bool`. Every exported func in this
package obeys that rule.

- IDs are `int64`. The underlying GORM models use `uint` — the shim casts
  internally. Send IDs as Dart `int` (which Flutter encodes as 64-bit on
  Android).
- Complex inputs/outputs flow as **UTF-8 JSON bytes**.
- Optional payloads accept either an empty `[]byte` or `{}` — both
  interpreted as "no overrides".

### Money serialization (decimal-as-string)

Every monetary value is `pkg/types.Money` which is a thin alias of
`shopspring/decimal.Decimal`. It marshals to JSON as a **string**:

```json
{"amount": "4.50"}
```

**Do not decode money as `num` / `double` on the Dart side** — you will
lose precision. Use [`package:decimal`](https://pub.dev/packages/decimal):

```dart
import 'package:decimal/decimal.dart';

final amount = Decimal.parse(json['amount'] as String);
```

When sending money in requests (e.g. transaction category amounts),
serialize from `Decimal` the same way:

```dart
{'category_id': 1, 'amount': amount.toString()}
```

### Date / time format

All dates and timestamps use **RFC 3339** strings, UTC preferred:

```
2026-06-13T20:27:58Z
```

In Dart:

```dart
DateTime.now().toUtc().toIso8601String()
```

### Identifiers

- `profile_id` — the active personal-finance profile. Stored once at
  `Init`/`Setup`, automatically applied to every other call.
- `user_id` — the underlying user account that owns the profile. Only the
  settings endpoints (`GetSettings`/`UpdateSettings`) need it, and the shim
  resolves it automatically from the active profile.

You **never** pass `profile_id` or `user_id` inside the JSON payload of
any non-lifecycle call. They are derived from the in-process state.

### Error model

Go `error`s propagate to the Flutter side as `PlatformException`. The
original Go error message lands in `e.message`.

Sentinel errors from the shim use stable strings — match on them if you
need to branch behavior:

| Sentinel | Cause |
|---|---|
| `mobile: Init has not been called` | Any call before `Init` |
| `mobile: Init has already been called` | Second `Init` without `Shutdown` |
| `mobile: profile id is not set; call SetProfileID or pass it to Init` | Crud call before `Setup` returned, or before `SetProfileID` was called |
| `mobile: invalid JSON payload: <encoder error>` | Malformed JSON in `payload` |

Service-layer errors propagate verbatim — examples:

- `record not found` (GORM, e.g. `GetTransaction` with bad id)
- `category name already exists` (`CreateCategory` duplicate)
- `recurrent_freq is required when is_recurrent is true` (validator)

Always wrap your `MethodChannel` calls in `try/catch` on the Kotlin side
and convert the exception into a `PlatformException` Dart can catch:

```kotlin
try {
    result.success(Mobilebridge.someCall(payload))
} catch (e: Exception) {
    result.error("MOBILE_ERROR", e.message, null)
}
```

---

## Lifecycle

### State machine

```
                    ┌──────────────┐
   process start →  │   not init   │
                    └──────┬───────┘
                           │ Init(dbPath, 0)            ▲
                           │ Init(dbPath, <known pid>)  │
                           ▼                            │ Shutdown()
                    ┌──────────────────┐                │
                    │   initialized    │────────────────┘
                    │  profile? maybe  │
                    └──┬───────────┬───┘
              first    │           │   returning user
              run      │           │   (Init was called
                       ▼           │    with profileID > 0)
                Setup(payload)     │
                   stores          ▼
                 profile_id   CRUD endpoints
                       │           ▲
                       └───────────┘
```

### First-run vs returning-user paths

**First run (no profile stored locally yet):**

```dart
await Mobilebridge.init(dbPath: dbPath, profileId: 0);
final setupJson = await Mobilebridge.setup({
  'first_name': 'Yusuf',
  'last_name':  'Doe',
  'currency_code': 'USD',
});
final profileId = setupJson['profile_id'] as int;
// Persist profileId to shared_preferences for next launch.
```

`Setup` automatically calls `SetProfileID(profile_id)` internally, so the
very next CRUD call (e.g. `CreateTransaction`) works without an extra
round-trip.

**Returning user:**

```dart
final profileId = prefs.getInt('profile_id')!;
await Mobilebridge.init(dbPath: dbPath, profileId: profileId);
// CRUD is now ready.
```

---

## Lifecycle endpoints

### `Init(dbPath, profileID) error`

Opens the SQLite database, runs migrations, seeds missing merchant keywords
from the bundled dictionary, loads the icon cache, and (optionally) stores
the active profile id. This runs before Flutter leaves its loading screen
and requires no internet connection.

Each startup checks individual keywords, inserts only missing entries, and
preserves existing mappings. Existing transactions whose saved icon and color
match a category are treated as legacy category fallbacks and refreshed.
Other nonempty legacy values are preserved. Automatic and explicit choices
are tracked separately for icon and color; later transaction edits refresh
automatic values. These internal source fields are not exposed in JSON.

**Idempotent?** No. Second call without `Shutdown` returns
`ErrAlreadyInited`. Use this to defend against double-init on app resume.

| Arg | Type | Notes |
|---|---|---|
| `dbPath` | `string` | **Absolute path** to the SQLite file. Use Flutter `path_provider` (`getApplicationSupportDirectory()`) and append `moneef/db.sqlite`. Parent dir is created if missing. |
| `profileID` | `int64` | `0` on first run (Setup will assign one). Otherwise the previously-stored profile id. |

**Returns:** `error` only.

**Errors:**

- `mobile.Init: dbPath must not be empty`
- `mobile.Init: config was already initialized with a different db path …` — process was already pinned to a different db path (config is a `sync.Once` singleton). Restart the process to switch databases.
- `mobile.Init: db connect: <gorm error>`
- `mobile.Init: migrate: <gorm error>`
- `mobile.Init: prepare icons: <error>`

**Side effects:**

- Creates `<dbPath>` and the parent dir if missing.
- Creates the FTS5 virtual table `icon_lookups_fts` if the bundled SQLite
  supports it (modernc does).
- Seeds missing icon mappings and upgrades legacy transaction icons atomically.
  Transaction amounts, categories, dates, and edit timestamps are unchanged.
- Sets the package-level `dbHandle` and `profileID`.

**Kotlin:**

```kotlin
"init" -> {
    val dbPath = call.argument<String>("dbPath")!!
    val pid    = (call.argument<Number>("profileId") ?: 0).toLong()
    Mobilebridge.init(dbPath, pid)
    result.success(null)
}
```

**Dart:**

```dart
final dir = await getApplicationSupportDirectory();
final dbPath = '${dir.path}/moneef/db.sqlite';
await _channel.invokeMethod('init', {'dbPath': dbPath, 'profileId': storedProfileId ?? 0});
```

---

### `SetProfileID(id) error`

Replaces the active profile id without re-opening the database. Useful for
multi-profile UIs (none today, but kept for future-proofing).

| Arg | Type | Notes |
|---|---|---|
| `id` | `int64` | Must be `> 0`. |

**Returns:** `error`. Pre-conditions: `Init` must have been called.

**Kotlin:**

```kotlin
"setProfileId" -> {
    val id = (call.argument<Number>("id") ?: 0).toLong()
    Mobilebridge.setProfileID(id)
    result.success(null)
}
```

---

### `Shutdown() error`

Closes the underlying `*sql.DB` and clears `dbHandle` / `profileID`.

Safe to call before `Init` — returns `nil` in that case. Recommended
during `onDestroy()` of the Flutter activity for clean DB file handles.

**Kotlin:**

```kotlin
"shutdown" -> { Mobilebridge.shutdown(); result.success(null) }
```

---

## Setup

### `Setup(payload) → []byte`

First-run user + profile + settings creation. **Only callable when
`Init` has succeeded.** Atomically creates 3 rows in a transaction.

**Request JSON:**

```json
{
  "first_name": "Yusuf",
  "last_name":  "Doe",
  "currency_code": "USD",
  "language": "en",
  "exchange_rate_api_key": ""
}
```

| Field | Required | Validation |
|---|---|---|
| `first_name` | yes | non-empty |
| `last_name` | yes | non-empty |
| `currency_code` | yes | exactly 3 chars |
| `language` | no | defaults to `"en"` |
| `exchange_rate_api_key` | no | optional |

**Response JSON:**

```json
{
  "profile_id": 1,
  "user_id":    1,
  "first_name": "Yusuf",
  "last_name":  "Doe",
  "currency_code": "USD",
  "language": "en"
}
```

`profile_id` is what you should store in `shared_preferences` and pass to
`Init` on subsequent launches. The shim has **already** set it as the
active profile id by the time this function returns, so the very next call
(e.g. `CreateCategory`) works.

**Errors:**

- `ErrNotInitialized` — `Init` was not called.
- `ErrInvalidPayload` — JSON parse failure.
- Validator failures (`first_name is required`, etc.).
- DB transaction errors (`failed to create user: …`).

**Dart:**

```dart
Future<Map<String, dynamic>> setup({
  required String firstName,
  required String lastName,
  required String currencyCode,
  String language = 'en',
}) async {
  final body = utf8.encode(jsonEncode({
    'first_name': firstName,
    'last_name':  lastName,
    'currency_code': currencyCode,
    'language': language,
  }));
  final bytes = await _channel.invokeMethod<Uint8List>('setup', {'payload': body});
  return jsonDecode(utf8.decode(bytes!)) as Map<String, dynamic>;
}
```

---

## Transactions

### `CreateTransaction(payload) → []byte`

Creates a one-off transaction or, when `is_recurrent: true`, a recurrence
template AND its first booked transaction.

**Request JSON (one-off expense):**

```json
{
  "transaction_name": "Morning latte",
  "currency_code": "USD",
  "transaction_type": "expense",
  "date": "2026-06-13T08:30:00Z",
  "icon": "mdi:coffee",
  "color": "#7B3F00",
  "merchant_name": "Blue Bottle",
  "notes": "Pre-meeting caffeine",
  "transaction_categories": [
    {"category_id": 1, "amount": "4.50"}
  ]
}
```

**Request JSON (recurrent subscription with finite end):**

```json
{
  "transaction_name": "Netflix",
  "currency_code": "USD",
  "transaction_type": "expense",
  "date": "2026-06-01T00:00:00Z",
  "icon": "mdi:netflix",
  "color": "#E50914",
  "is_recurrent": true,
  "recurrent_freq": "monthly",
  "is_active_recurrent": true,
  "recurrent_has_end_date": true,
  "recurrent_end_date": "2027-06-01T00:00:00Z",
  "recurrent_total_amount": "180.00",
  "recurrent_paid_previously": "0.00",
  "transaction_categories": [
    {"category_id": 4, "amount": "15.00"}
  ]
}
```

| Field | Required | Type | Notes |
|---|---|---|---|
| `transaction_name` | yes | string | |
| `currency_code` | yes | string(3) | |
| `transaction_type` | yes | `"expense"` \| `"income"` | |
| `date` | yes | RFC3339 | |
| `icon`, `color` | no | string | resolved before returning on mobile when blank; explicit values are preserved |
| `merchant_name`, `notes` | no | string | |
| `transaction_categories` | yes | array, min 1 | duplicates rejected |
| `transaction_categories[].category_id` | yes | uint > 0 | must exist |
| `transaction_categories[].amount` | yes | decimal-string > 0 | |
| `is_recurrent` | no | bool | |
| `recurrent_freq` | iff `is_recurrent` | `daily`\|`weekly`\|`bi-weekly`\|`monthly`\|`yearly` | |
| `is_active_recurrent` | no | bool | defaults true |
| `recurrent_has_end_date` | no | bool | |
| `recurrent_end_date` | iff `has_end_date` | RFC3339 | must be ≥ `date` |
| `recurrent_total_amount` | iff `has_end_date` | decimal-string > 0 | |
| `recurrent_paid_previously` | iff `has_end_date` | decimal-string ≥ 0 | ≤ `recurrent_total_amount` |

**Response JSON:**

```json
{"message": "transaction created"}
```

**Errors:** validator + service errors; `record not found` if a category id
does not belong to the profile.

---

### `ListTransactions(payload) → []byte`

Filtered, paginated list. **Replaces the HTTP `GET /transactions?…` query
params** with a single JSON object.

**Request JSON (all optional):**

```json
{
  "type": "expense",
  "category_id": 1,
  "category_name": "Food",
  "date_from": "2026-06-01T00:00:00Z",
  "date_to":   "2026-06-30T23:59:59Z",
  "search": "latte",
  "sort": "-date",
  "page": 1,
  "per_page": 20
}
```

Defaults: `page=1`, `per_page=20`. `per_page` is capped at `100`.
Pass `{}` (or empty bytes) to list everything.

**Response JSON:**

```json
{
  "count": 142,
  "total_pages": 8,
  "current_page": 1,
  "per_page": 20,
  "results": [
    {
      "id": 1,
      "created_at": "2026-06-13T20:27:58Z",
      "updated_at": "2026-06-13T20:27:58Z",
      "profile_id": 1,
      "name": "Morning latte",
      "type": "expense",
      "date": "2026-06-13T08:30:00Z",
      "currency_code": "USD",
      "icon": "mdi:coffee",
      "color": "#7B3F00",
      "merchant_name": "Blue Bottle",
      "TransactionCategory": [
        {
          "id": 1,
          "transaction_id": 1,
          "category_id": 1,
          "Category": {
            "id": 1, "name": "Food", "icon": "mdi:food", "color": "#FF6B6B", "type": "expense"
          },
          "amount": "4.50"
        }
      ]
    }
  ]
}
```

> **No `next`/`previous` URLs.** The HTTP paginator emits them; gomobile
> drops them because they're meaningless in-process. Compute pagination
> state from `page` + `per_page` directly.

---

### `GetTransaction(id) → []byte`

Returns one transaction with `TransactionCategory` (with `Category`
preloaded) and `RecurrenceTemplate` if any.

| Arg | Type |
|---|---|
| `id` | `int64` > 0 |

**Response JSON:** the same `Transaction` shape shown above.

**Errors:** `record not found` if id doesn't belong to the profile.

---

### `UpdateTransaction(id, payload) → []byte`

Partial update. Omit fields you don't want to change.

**Request JSON:** same shape as `CreateTransaction` minus recurrence
controls; all fields are optional. If `transaction_categories` is
provided, it **replaces** the entire category list (and duplicates are
rejected).

**Response JSON:**

```json
{"message": "transaction updated"}
```

---

### `DeleteTransaction(id) error`

Cascade-deletes the `TransactionCategory` rows then the transaction.

**Errors:** `transaction not found` if id ∉ profile.

---

## Recurrences

Recurrences are created **alongside** a transaction (via the
`is_recurrent: true` form of `CreateTransaction`). These endpoints manage
the templates themselves.

### `ListRecurrences() → []byte`

Returns `[]RecurrenceTemplate` for the active profile.

**Response JSON:**

```json
[
  {
    "id": 1,
    "profile_id": 1,
    "name": "Netflix",
    "type": "expense",
    "currency_code": "USD",
    "icon": "mdi:netflix",
    "color": "#E50914",
    "frequency": "monthly",
    "next_date": "2026-07-01T00:00:00Z",
    "next_payment_amount": "15.00",
    "amount_paid_previously": "30.00",
    "amount_left_to_pay": "135.00",
    "total_amount_to_pay": "180.00",
    "end_date": "2027-06-01T00:00:00Z",
    "start_date": "2026-06-01T00:00:00Z",
    "has_end_date": true,
    "is_active": true,
    "transaction_category": [
      {"id": 1, "category_id": 4, "Category": {…}, "amount": "15.00"}
    ]
  }
]
```

---

### `RecurrenceTimeline() → []byte`

30-day forward + backward projection of all active recurrences, sorted by
date. Useful for calendar-style UIs.

**Response JSON:**

```json
[
  {
    "id": 1,
    "name": "Netflix",
    "type": "expense",
    "amount": "15.00",
    "currency": "USD",
    "icon": "mdi:netflix",
    "color": "#E50914",
    "date": "2026-06-01T00:00:00Z"
  },
  {
    "id": 1,
    "name": "Netflix",
    "amount": "15.00",
    "date": "2026-07-01T00:00:00Z",
    "…": "…"
  }
]
```

`amount` is converted into the profile's settings currency where possible
(falls back to the template's native currency if no rate exists).

---

### `UpdateRecurrence(id, payload) error`

Saves a recurring payment's editable details in the active profile's local
database. The mobile editor sends the complete form:

```json
{
  "name": "Rent",
  "frequency": "monthly",
  "next_date": "2026-10-01T00:00:00Z",
  "has_end_date": true,
  "end_date": "2027-09-30T23:59:59Z",
  "is_active": true,
  "merchant_name": "Landlord",
  "notes": "Monthly rent"
}
```

`name`, `frequency`, `next_date`, `has_end_date`, and `is_active` are required.
Frequency accepts `daily`, `weekly`, `bi-weekly`, `monthly`, or `yearly`.
When `has_end_date` is true, `end_date` is required and must be on or after
`next_date`. Setting `has_end_date` to false clears the saved end date.
Empty notes and merchant strings clear those fields. Unknown fields are rejected.

This changes the template's schedule and details. Amounts, currencies,
categories, payment type, and recorded transactions remain unchanged.
The Android bridge schedules the existing automatic local backup after success.

---

### `DeleteRecurrence(id) error`

Deletes the recurrence template. Already-booked transactions referring to
it stay but `recurrence_template_id` becomes a dangling FK (matches HTTP
behavior).

---

## Categories

### `ListCategories(payload) → []byte`

| Field | Type | Notes |
|---|---|---|
| `type` | string | `"expense"` \| `"income"` \| `""` (both) |
| `custom` | bool | only profile-owned categories |
| `used` | bool | only categories that have ≥1 transaction |

Pass `{}` for everything.

**Response JSON:**

```json
[
  {
    "id": 1,
    "created_at": "…",
    "updated_at": "…",
    "profile_id": 1,
    "type": "expense",
    "name": "Food",
    "icon": "mdi:food",
    "color": "#FF6B6B"
  }
]
```

---

### `CreateCategory(payload) → []byte`

**Request JSON:**

```json
{
  "name":  "Coffee",
  "type":  "expense",
  "icon":  "mdi:coffee",
  "color": "#7B3F00"
}
```

| Field | Required |
|---|---|
| `name` | yes |
| `type` | yes, `"expense"` \| `"income"` |
| `icon`, `color` | no (resolved async if blank) |

**Response JSON:** the created `Category` with `id` and `profile_id`
populated.

**Errors:** `category name already exists` on duplicate.

---

### `UpdateCategory(id, payload) error`

Partial update. Omit fields you don't want to change.

**Request JSON:** `{name?, icon?, color?}`. Empty payload = no-op.

---

### `DeleteCategory(id) error`

Removes the category. Existing transactions retain the relationship via
`TransactionCategory.category_id` even if the category row is gone.

---

## Dashboard

### `Dashboard(payload) → []byte`

Single call that builds the home-screen summary for a date range.

**Request JSON (both optional, defaults to current calendar month):**

```json
{
  "date_from": "2026-06-01T00:00:00Z",
  "date_to":   "2026-06-30T23:59:59Z"
}
```

**Response JSON:**

```json
{
  "period": {
    "start_date": "2026-06-01T00:00:00Z",
    "end_date":   "2026-06-30T23:59:59Z"
  },
  "currency_code": "USD",
  "balance":       "-4.50",
  "total_income":  "0",
  "total_expense": "4.50",
  "recent_transactions": [ {Transaction}, … up to 10 ],
  "quick_stats": {
    "top_category": {
      "category_id":   1,
      "category_name": "Food",
      "total_amount":  "4.50"
    },
    "avg_daily_spend":    "0.15",
    "transaction_count":  1,
    "savings_rate":       "0",
    "biggest_transaction": {
      "name":  "Morning latte",
      "amount": "4.50",
      "icon":  "mdi:coffee",
      "color": "#7B3F00"
    },
    "top_merchant": {"name": "Blue Bottle", "amount": "4.50"},
    "avg_transaction": "4.50"
  },
  "upcoming_recurring": [
    {"name": "Netflix", "amount": "15.00", "date": "2026-07-01T00:00:00Z"}
  ]
}
```

Notes:

- `currency_code` is taken from `UserSettings.currency_code`; all amounts
  in the response are converted into that currency where possible.
- `top_category` is `null` if no expenses in the period.
- `upcoming_recurring` is the next 5 within ~30 days.

---

## Analysis

### `Analysis(payload) → []byte`

Heavier endpoint that runs 9 parallel queries (errgroup-driven). Produces
chart data for the spending-by-category screen and a period-over-period
comparison.

**Request JSON:**

```json
{
  "start_date": "2026-06-01T00:00:00Z",
  "end_date":   "2026-06-30T23:59:59Z",
  "currency":   "USD",
  "tz_offset_minutes": 180
}
```

| Field | Required | Notes |
|---|---|---|
| `start_date` | yes | RFC3339 |
| `end_date` | yes | RFC3339 |
| `currency` | no | if empty, resolved from `UserSettings.currency_code` |
| `tz_offset_minutes` | no | device UTC offset (e.g. `180` for UTC+3); `spent_per_day` is grouped by calendar days in that zone. Default `0` (UTC days) |

Each `spent_per_day` date is the calendar day at UTC midnight
(`2026-06-01T00:00:00Z` means June 1 in the requested zone).

The shim automatically derives the "last period" as the same-length window
ending at `start_date`.

**Response JSON:**

```json
{
  "categories": [
    {
      "category_id":   1,
      "category_name": "Food",
      "total_amount":  "120.00",
      "percentage":    "42.10",
      "icon":  "mdi:food",
      "color": "#FF6B6B"
    }
  ],
  "categories_last_period": [ … same shape … ],
  "spent_per_day": [
    {"date": "2026-06-01T00:00:00Z", "amount": "3.50"},
    {"date": "2026-06-02T00:00:00Z", "amount": "0"}
  ],
  "spent_per_day_last_period": [ … same shape … ],
  "next_recurring_transactions": [
    {"amount": "15.00", "date": "2026-07-01T00:00:00Z", "name": "Netflix"}
  ],
  "total": "285.20",
  "quick_stats": {
    "savings_rate":        "12.5",
    "biggest_transaction": {"name": "…", "amount": "…", "icon": "…", "color": "…"},
    "transaction_count":   14,
    "top_merchant":        {"name": "Blue Bottle", "amount": "27.00"},
    "avg_transaction":     "20.37"
  }
}
```

Note that `quick_stats` here has a **different shape** from the
dashboard's `quick_stats` (no `top_category`, no `avg_daily_spend`).

`spent_per_day` is **gap-filled** — every day in the window has an entry,
with `"0"` for empty days.

---

## Patterns

Patterns are heuristic insights about the user's spending. Three
detectors run today:

| Detector | Min transactions | What it looks for |
|---|---|---|
| Weekend Spike | 30 | Weekend vs weekday avg spending differing by >30% |
| Category-Based Spending | 10 | Top category + concentration (top 1 ≥ 30%, top 2 ≥ 80%) |
| Purchase Frequency | 50 | Daily habits, weekly repeats, infrequent splurges per category |

### Pattern detection model

There are **two** funcs: a fast read (`Patterns`) and a (re-)compute
(`RefreshPatterns`). Typical UI flow:

```
App opens                                       
  → Patterns()       // instant; reads cached rows
      ↓
  → render list                                  
                                                
User pulls to refresh / opens insights screen:
  → RefreshPatterns({})  // recomputes + upserts; can take 100ms-2s
      ↓
  → render returned list (already sorted by final_score DESC)
```

`RefreshPatterns` writes the detected patterns into the `patterns` table
via `ON CONFLICT (profile_id, name, type) DO UPDATE`. Subsequent
`Patterns()` calls return the freshly-stored set.

### Pattern type catalog

Every detected pattern has a `pattern_type` string. Switch on it in your
UI to pick an icon / template / explanation:

| `pattern_type` | Source detector | Trigger |
|---|---|---|
| `weekend_spike` | WeekendSpike | Weekend avg > weekday avg by ≥ 30% |
| `weekday_spike` | WeekendSpike | Weekday avg > weekend avg by ≥ 30% |
| `top_category` | CategoryBased | Always (top spending category) |
| `high_concentration` | CategoryBased | Top 1 category ≥ 30% of total |
| `very_high_concentration` | CategoryBased | Top 2 ≥ 80% of total |
| `daily_habit` | PurchaseFrequency | ≥ 5 tx & (≥ 4/week OR median ≤ 2 days) |
| `weekly_repeat` | PurchaseFrequency | ≥ 4 tx & median interval 3-5 days |
| `infrequent_splurge` | PurchaseFrequency | ≤ 6 tx & avg ≥ 60 & total ≥ 100 (in currency units) |

### `Patterns() → []byte`

Reads persisted patterns for the active profile. **No DB-write.** Sorted
by `final_score DESC`.

**Request:** no args.

**Response JSON:**

```json
[
  {
    "id": 12,
    "created_at": "2026-06-13T22:00:00Z",
    "updated_at": "2026-06-13T22:00:00Z",
    "name": "Daily Habit: Food",
    "description": "'Food' appears to be a daily habit with 18 purchases (4.2 per week) and a median interval of 1.5 days between purchases. (period: 2026-05-13 to 2026-06-13)",
    "metadata": {
      "category": "Food",
      "transactionCount": 18,
      "purchasesPerWeek": 4.2,
      "medianInterval": 1.5,
      "totalAmount": 87.50,
      "averageAmount": 4.86,
      "patternType": "daily_habit"
    },
    "icon": "",
    "color": "",
    "pattern_type": "daily_habit",
    "final_score": 7.42,
    "profile_id": 1
  },
  {
    "id": 13,
    "name": "Weekend Spending Spike",
    "description": "Your average weekend spending ($48.20) is 64.5% higher than your weekday spending ($29.30). Consider reviewing your weekend expenses.",
    "metadata": {
      "weekendAvg": 48.2,
      "weekdayAvg": 29.3,
      "percentDiff": 0.645,
      "totalAmount": 1245.50,
      "totalAvg": 18.32,
      "transactionsCount": 68
    },
    "pattern_type": "weekend_spike",
    "final_score": 6.18,
    "…": "…"
  }
]
```

**Empty result:** `[]` (never `null`).

**`metadata` shape per `pattern_type`:**

The `metadata` field is polymorphic — its shape depends on `pattern_type`.
Decode it as `dynamic` / `Map<String, dynamic>` in Dart and key into it
based on the type. Numeric values are JSON numbers (not strings — these
are detector internals, not user money).

```dart
switch (pattern['pattern_type']) {
  case 'weekend_spike':
  case 'weekday_spike':
    final m = pattern['metadata'] as Map<String, dynamic>;
    final weekendAvg  = (m['weekendAvg']  as num).toDouble();
    final weekdayAvg  = (m['weekdayAvg']  as num).toDouble();
    final percentDiff = (m['percentDiff'] as num).toDouble();   // 0.645 = 64.5%
    // …
    break;

  case 'top_category':
  case 'high_concentration':
  case 'very_high_concentration':
    final m = pattern['metadata'] as Map<String, dynamic>;
    final category   = m['category']   as String;
    final percentage = (m['percentage'] as num).toDouble();     // 42.1 = 42.1%
    break;

  case 'daily_habit':
  case 'weekly_repeat':
  case 'infrequent_splurge':
    final m = pattern['metadata'] as Map<String, dynamic>;
    final category         = m['category']         as String;
    final txCount          = (m['transactionCount']  as num).toInt();
    final purchasesPerWeek = (m['purchasesPerWeek']  as num?)?.toDouble();   // null for infrequent_splurge
    final medianInterval   = (m['medianInterval']    as num?)?.toDouble();   // null for infrequent_splurge
    final totalAmount      = (m['totalAmount']       as num).toDouble();
    final averageAmount    = (m['averageAmount']     as num).toDouble();
    break;
}
```

> **Money values inside `metadata` are JSON `number`, not decimal-string.**
> They are derived stats, not user-entered amounts — precision drift here
> is acceptable. **User-facing money** (transactions, recurrences, dashboard
> amounts) is always decimal-string elsewhere in the API.

**Errors:** `ErrNotInitialized`, `ErrProfileNotSet`, plus any GORM read
error.

**Kotlin:**

```kotlin
"patterns" -> result.success(Mobilebridge.patterns())
```

**Dart:**

```dart
Future<List<Map<String, dynamic>>> patterns() async {
  final bytes = await _channel.invokeMethod<Uint8List>('patterns');
  final raw = jsonDecode(utf8.decode(bytes!)) as List;
  return raw.cast<Map<String, dynamic>>();
}
```

---

### `RefreshPatterns(payload) → []byte`

Re-runs all detectors against the active profile's transactions and
upserts the results. **Writes** to the `patterns` table.

**Request JSON (all optional):**

```json
{
  "start_date": "2026-05-01T00:00:00Z",
  "end_date":   "2026-06-01T00:00:00Z"
}
```

- Pass `{}` to analyze the user's **entire history** (recommended for the
  scheduled refresh).
- Pass both dates to scope analysis to a window (e.g. for "Last 30 days"
  insights).

Internally:

1. Loads all expense transactions for the profile (optionally filtered to
   the window) with categories preloaded.
2. Normalizes amounts to `UserSettings.currency_code` via stored exchange
   rates (best-effort — non-convertible amounts pass through unchanged).
3. Calculates `TransactionStats` (total, avg, count, min/max date).
4. Runs each detector that meets its `MinTransactions()` floor.
5. Scores every produced pattern via the detector's `ScorePattern`
   (weighted: impact 0.4 · confidence 0.3 · action 0.1 · urgency 0.2).
6. Sorts by `final_score DESC` and returns the slice. **Note:** the
   returned slice is the in-memory result; persisting via
   `repository.UpsertPatterns` is a separate step that today only the HTTP
   handler invokes. If you need the persisted set, follow up with
   `Patterns()`.

**Response JSON:** array of patterns identical in shape to `Patterns()`.

**Errors:**

- `ErrNotInitialized`, `ErrProfileNotSet`
- `failed to fetch transactions: …`
- `failed to get currency code: …`
- `error calculating transaction stats: …`
- `error in detector <Type>: …`

**Performance notes:**

- Pattern detection is O(n) over transactions per detector, with one extra
  per-category sort in the frequency detector. 1000 transactions → ~50ms
  on a mid-tier Android device.
- Always call **off the main isolate** in Dart if you anticipate >100ms
  latency. The `MethodChannel` call itself is already async, but the JNI
  hop holds the platform thread.

**Kotlin:**

```kotlin
"refreshPatterns" -> {
    val payload = call.argument<ByteArray>("payload") ?: "{}".toByteArray()
    result.success(Mobilebridge.refreshPatterns(payload))
}
```

**Dart (full example):**

```dart
Future<List<Map<String, dynamic>>> refreshPatterns({
  DateTime? startDate,
  DateTime? endDate,
}) async {
  final body = utf8.encode(jsonEncode({
    if (startDate != null) 'start_date': startDate.toUtc().toIso8601String(),
    if (endDate   != null) 'end_date':   endDate.toUtc().toIso8601String(),
  }));
  final bytes = await _channel.invokeMethod<Uint8List>(
    'refreshPatterns',
    {'payload': body},
  );
  final raw = jsonDecode(utf8.decode(bytes!)) as List;
  return raw.cast<Map<String, dynamic>>();
}
```

**End-to-end usage example:**

```dart
// 1. Cheap render on screen open
final cached = await mobile.patterns();
setState(() => _patterns = cached);

// 2. Triggered by pull-to-refresh
final fresh = await compute(_runRefresh, null); // off main isolate
setState(() => _patterns = fresh);

// In a top-level function for `compute`:
Future<List<Map<String, dynamic>>> _runRefresh(_) async {
  return MoneefCore.instance.refreshPatterns();
}
```

**UI integration tip:** `final_score` is the canonical sort key. The
backend already sorts the returned slice — preserve that order in the UI.
Trim to top-N (3-5) for the "insights" home-screen card; show the full
list on a dedicated screen.

---

## Profile & settings

### `GetProfile() → []byte`

Merges `Profile` + `User` records (the HTTP handler does this server-side;
the shim does the same merge in-process).

**Response JSON:**

```json
{
  "id": 1,
  "first_name": "Yusuf",
  "last_name": "Doe",
  "email": "yusuf@example.com",
  "birthday": "1995-03-12T00:00:00Z"
}
```

`email` may be empty string for users created via `Setup` (which does not
collect email today).

---

### `UpdateProfile(payload) error`

**Request JSON:**

```json
{"first_name": "Yusuf", "last_name": "Doe"}
```

Both required, non-empty.

---

### `GetSettings() → []byte`

Resolves `user_id` from the active profile internally, then fetches
settings.

**Response JSON:**

```json
{
  "currency_code": "USD",
  "language": "en",
  "is_notification_enabled": true,
  "is_dark_mode": false,
  "exchange_rate_api_key": ""
}
```

---

### `UpdateSettings(payload) error`

Partial update. All fields optional pointers — omit to leave unchanged.

**Request JSON:**

```json
{
  "currency_code": "EUR",
  "language": "en",
  "is_notification_enabled": true,
  "is_dark_mode": true,
  "exchange_rate_api_key": "abcdef0123"
}
```

`language` validated as `"en"` or `"ar"`. `currency_code` must be 3 chars.

---

## Currencies & exchange rates

### `ListCurrencies() → []byte`

All supported currencies, ordered by code. Needs `Init` only (no active
profile), same as the public `GET /api/v1/currencies`.

**Response JSON:**

```json
[{"code": "USD", "name": "US Dollar", "symbol": "$"}]
```

---

### `ListExchangeRates(payload) → []byte`

Stored rates whose `currency_code_2` is `base`, ordered by
`currency_code_1`. Payload may be empty; `base` then defaults to the
profile's `currency_code` setting.

**Request JSON:**

```json
{"base": "USD"}
```

**Response JSON:**

```json
[
  {
    "id": 3,
    "created_at": "2026-09-01T10:00:00Z",
    "updated_at": "2026-09-01T10:00:00Z",
    "currency_code_1": "EUR",
    "currency_code_2": "USD",
    "rate": "1.08",
    "last_updated": "2026-09-01T10:00:00Z"
  }
]
```

---

### `UpsertExchangeRate(payload) error`

Manually sets a rate. Writes both directions: `from → to` at `rate` and
`to → from` at `1 / rate`.

**Request JSON:**

```json
{"from": "EUR", "to": "USD", "rate": "1.08"}
```

All three required. `rate` is a decimal string and must be `> 0`.

---

### `FetchExchangeRates() error`

Pulls fresh rates from the exchange-rate API using the
`exchange_rate_api_key` from settings. Fails with
`no exchange rate API key configured` when that key is empty.

---

## Building the AAR

See [README.md](./README.md#producing-the-aar) for the gomobile setup and
bind command.

---

## Local backup functions

- `ActiveProfileID() int64`: returns the active selection, including the profile
  recovered from a restored database. Zero means setup or restore is needed.
- `CreateBackup(path string) ([]byte, error)`: writes a new versioned local ZIP
  snapshot and returns its JSON manifest. The destination must not exist.
- `RestoreBackup(path string) ([]byte, error)`: validates an archive, replaces
  the current database with crash recovery, selects its profile, and returns
  the manifest. Requires `Init`, but does not require `Setup` on a new install.

Android serializes these operations with CRUD on the native worker. Its separate
`moneef/backups` channel handles local folder selection, status, automatic
backup, listing, and restoration.

## Out-of-process smoke test

Run the in-process JSON contract end-to-end on a Linux/macOS dev box (no
Android device needed):

```bash
go run -tags=smoke ./mobilebridge/_smoke
```

This exercises `Init → Setup → CreateCategory → CreateTransaction →
ListTransactions → GetTransaction → Dashboard` against a tempfile SQLite
DB and prints every JSON payload it sees. It does **not** test JNI
marshaling — that requires a real Android device or emulator — but it's
the fastest way to catch shim regressions.
