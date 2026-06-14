# `mobile/` — gomobile bindings for Flutter

This package exposes the Moneef Go core as a JNI-compatible Android library
(`.aar`). The Flutter Android app calls into the library through a Kotlin
`MethodChannel` shim; iOS is not yet wired.

> **Looking for the full API reference?** Every function's request /
> response JSON schema, error catalog, Kotlin handler, and Dart caller is
> documented in **[API.md](./API.md)**. This README covers build setup and
> a 60-second usage example only.

## Build constraints

Every file under `mobile/` is gated by `//go:build android`. Default builds
(`go build ./...`, `go test ./tests/...`, `wails dev`) ignore this package
entirely.

To verify the source compiles for Android without invoking `gomobile`:

```bash
GOOS=android CGO_ENABLED=0 GOARCH=arm64 go build ./mobile/...
```

## Producing the `.aar`

Install `gomobile` once:

```bash
go install golang.org/x/mobile/cmd/gomobile@latest
go install golang.org/x/mobile/cmd/gobind@latest
gomobile init
```

Then bind:

```bash
gomobile bind -target=android -androidapi 21 -o build/moneef.aar ./mobile
```

Output:

- `build/moneef.aar` — drop into `android/app/libs/` of the Flutter project.
- `build/moneef-sources.jar` — sources for Android Studio's debugger.

## Exported API

All signatures use only types gomobile can marshal: `string`, `[]byte`,
`int64`, `error`, `bool`. Numeric IDs are `int64` (Go's `uint` is not
bridgeable). Complex payloads pass as JSON bytes.

| Function | Description |
|---|---|
| `Init(dbPath string, profileID int64) error` | Open SQLite at `dbPath`, run migrations, load icon cache, optionally set the active profile. Call once at startup. `profileID = 0` if not yet known (first run). |
| `Shutdown() error` | Close the DB connection cleanly. Safe to call before exit. |
| `SetProfileID(id int64) error` | Switch the active profile without re-opening the DB. |
| `Setup(payload []byte) ([]byte, error)` | First-run user + profile + settings creation. Stores the new profile id automatically. Returns `{profile_id, user_id, first_name, last_name, currency_code, language}`. |
| `CreateTransaction(payload []byte) ([]byte, error)` | |
| `ListTransactions(payload []byte) ([]byte, error)` | Inline pagination. See `ListTransactionsRequest`. |
| `GetTransaction(id int64) ([]byte, error)` | |
| `UpdateTransaction(id int64, payload []byte) ([]byte, error)` | |
| `DeleteTransaction(id int64) error` | |
| `ListRecurrences() ([]byte, error)` | |
| `RecurrenceTimeline() ([]byte, error)` | |
| `DeleteRecurrence(id int64) error` | |
| `ListCategories(payload []byte) ([]byte, error)` | |
| `CreateCategory(payload []byte) ([]byte, error)` | |
| `UpdateCategory(id int64, payload []byte) error` | |
| `DeleteCategory(id int64) error` | |
| `Dashboard(payload []byte) ([]byte, error)` | |
| `Analysis(payload []byte) ([]byte, error)` | If `currency` is empty, resolved from user settings. |
| `Patterns() ([]byte, error)` | |
| `RefreshPatterns(payload []byte) ([]byte, error)` | |
| `GetProfile() ([]byte, error)` | |
| `UpdateProfile(payload []byte) error` | |
| `GetSettings() ([]byte, error)` | |
| `UpdateSettings(payload []byte) error` | |

## Money / decimal serialization

`pkg/types.Money` (alias for `shopspring/decimal.Decimal`) marshals to JSON
as a **string**, e.g. `"10.50"`. The Flutter side must use
[`package:decimal`](https://pub.dev/packages/decimal) and `Decimal.parse`:

```dart
final amount = Decimal.parse(json['amount'] as String);
```

Do NOT decode amounts as `num` / `double` — you will lose precision.

## Error handling

Go errors propagate to the Kotlin side as `java.lang.Exception`. On the
Flutter side they surface as `PlatformException` with the original Go error
message in `details`. Sentinel errors are stable strings and may be matched
on:

- `mobile: Init has not been called`
- `mobile: Init has already been called`
- `mobile: profile id is not set; call SetProfileID or pass it to Init`
- `mobile: invalid JSON payload: <encoder error>`

## Kotlin `MethodChannel` shim

Place under `android/app/src/main/kotlin/com/moneef/app/`:

```kotlin
package com.moneef.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import mobile.Mobile

class MainActivity : FlutterActivity() {
    private val channelName = "com.moneef.app/core"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "init" -> {
                            val dbPath = call.argument<String>("dbPath")!!
                            val profileId = (call.argument<Number>("profileId") ?: 0).toLong()
                            Mobile.init(dbPath, profileId)
                            result.success(null)
                        }
                        "shutdown" -> { Mobile.shutdown(); result.success(null) }
                        "setProfileId" -> {
                            val id = (call.argument<Number>("id") ?: 0).toLong()
                            Mobile.setProfileID(id)
                            result.success(null)
                        }
                        "setup" -> {
                            val payload = call.argument<ByteArray>("payload") ?: ByteArray(0)
                            result.success(Mobile.setup(payload))
                        }
                        "createTransaction" -> {
                            val payload = call.argument<ByteArray>("payload") ?: ByteArray(0)
                            result.success(Mobile.createTransaction(payload))
                        }
                        "listTransactions" -> {
                            val payload = call.argument<ByteArray>("payload") ?: ByteArray(0)
                            result.success(Mobile.listTransactions(payload))
                        }
                        "getTransaction" -> {
                            val id = (call.argument<Number>("id") ?: 0).toLong()
                            result.success(Mobile.getTransaction(id))
                        }
                        "deleteTransaction" -> {
                            val id = (call.argument<Number>("id") ?: 0).toLong()
                            Mobile.deleteTransaction(id)
                            result.success(null)
                        }
                        "dashboard" -> {
                            val payload = call.argument<ByteArray>("payload") ?: ByteArray(0)
                            result.success(Mobile.dashboard(payload))
                        }
                        // ... mirror the rest of the API surface ...
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("MOBILE_ERROR", e.message, null)
                }
            }
    }
}
```

`Mobile` is the auto-generated Java class that wraps the Go package. Method
names are lower-camel-cased (`Init` → `init`, `CreateTransaction` →
`createTransaction`).

## Dart caller

```dart
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:decimal/decimal.dart';
import 'dart:convert';

class MoneefCore {
  static const _channel = MethodChannel('com.moneef.app/core');

  Future<void> init({int profileId = 0}) async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = '${dir.path}/moneef/db.sqlite';
    await _channel.invokeMethod('init', {
      'dbPath': dbPath,
      'profileId': profileId,
    });
  }

  Future<Map<String, dynamic>> setup({
    required String firstName,
    required String lastName,
    required String currencyCode,
    String language = 'en',
  }) async {
    final payload = utf8.encode(jsonEncode({
      'first_name': firstName,
      'last_name': lastName,
      'currency_code': currencyCode,
      'language': language,
    }));
    final bytes = await _channel.invokeMethod<Uint8List>('setup', {'payload': payload});
    return jsonDecode(utf8.decode(bytes!)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> body) async {
    final payload = utf8.encode(jsonEncode(body));
    final bytes = await _channel.invokeMethod<Uint8List>('createTransaction', {'payload': payload});
    return jsonDecode(utf8.decode(bytes!)) as Map<String, dynamic>;
  }
}
```

### Quick smoke flow

```dart
final core = MoneefCore();
await core.init(); // profileId not yet known
final setup = await core.setup(
  firstName: 'Test', lastName: 'User', currencyCode: 'USD',
);
final profileId = setup['profile_id'] as int;
// store profileId in shared_preferences for next launch
await core.createTransaction({
  'transaction_name': 'Coffee',
  'currency_code': 'USD',
  'transaction_type': 'expense',
  'date': DateTime.now().toUtc().toIso8601String(),
  'icon': 'mdi:coffee',
  'color': '#000000',
  'transaction_categories': [
    {'category_id': 1, 'amount': '4.50'},
  ],
});
```

## Out-of-process smoke test

There is also a Go-only driver under `mobile/_smoke/` for validating the
JSON contract without an Android device:

```bash
go run -tags=smoke ./mobile/_smoke/
```

It opens a temp SQLite file, runs `Init` → `Setup` → `CreateTransaction` →
`ListTransactions` and prints the round-trip JSON. Useful for catching
regression in the shim without an Android NDK present. Note: the smoke
driver tags away the `//go:build android` files and links the package
without gomobile — so it is a *contract* test, not a JNI test.
