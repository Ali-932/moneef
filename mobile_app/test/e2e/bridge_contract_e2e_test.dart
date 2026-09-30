// T10 — Native bridge contract.
//
// Drives every `NativeApi` method (lib/services/native_api.dart) through the
// REAL `moneef/api` MethodChannel, backed by the real Go `mobilebridge` package
// over dart:ffi (see test/e2e/real_bridge.dart). No mocks below the channel.
//
// Tree:
//   10.1 every NativeApi method decodes against real Go
//   10.2 error sentinels propagate through PlatformException
//   10.3 static diff: MoneefBridge.kt vs native_api.dart vs mobilebridge/*.go
//   10.4 money/decimal serialization round trip
//
// Run: flutter test test/e2e/bridge_contract_e2e_test.dart

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/native_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'real_bridge.dart';

void main() {
  final bridge = RealBridge.instance;
  final api = NativeApi.instance;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bridge.resetWithProfile(); // fresh DB, Init'd, profile 1 set up
    bridge.install();
  });

  // ── 10.1 every NativeApi method decodes against real Go ────────────────
  group('10.1 NativeApi decoding against real Go', () {
    testWidgets('10.1.1 lifecycle + profile + settings shapes', (
      tester,
    ) async {
      final pid = await api.activeProfileId();
      expect(pid, isA<int>());
      expect(pid, 1, reason: 'first profile on a fresh DB is id 1');

      final profile = await api.getProfile();
      expect(profile, isA<Map<String, dynamic>>());
      expect(profile['id'], 1);
      expect(profile['first_name'], 'E2E');
      expect(profile['last_name'], 'Tester');
      expect(profile['email'], isA<String>());
      // ProfileResponse.Birthday is `*time.Time json:"birthday,omitempty"`
      // and unset here, so the key must be entirely absent, not JSON null.
      expect(
        profile.containsKey('birthday'),
        isFalse,
        reason: 'omitempty field must be absent, not decoded as null',
      );

      final settings = await api.getSettings();
      expect(settings['currency_code'], 'USD');
      expect(settings['language'], 'en');
      expect(settings['is_notification_enabled'], isA<bool>());
      expect(settings['is_dark_mode'], isA<bool>());
      expect(settings['exchange_rate_api_key'], isA<String>());

      // setProfileId is idempotent when re-set to the already-active id.
      await api.setProfileId(pid);
      expect(await api.activeProfileId(), pid);
    });

    testWidgets('10.1.2 empty-DB lists decode as [] — never null/crash', (
      tester,
    ) async {
      expect(await api.listRecurrences(), isA<List>());
      expect(await api.listRecurrences(), isEmpty);
      expect(await api.recurrenceTimeline(), isA<List>());
      expect(await api.recurrenceTimeline(), isEmpty);
      expect(await api.patterns(), isEmpty);
      // 0 transactions: every detector's MinTransactions guard skips it —
      // must come back as [] without an error (see pattern_engine.go).
      expect(await api.refreshPatterns(), isEmpty);
      expect(await api.listExchangeRates(), isEmpty);

      final currencies = await api.listCurrencies();
      expect(currencies, isNotEmpty, reason: 'seeded during Init');
      expect(currencies.first, isA<Map<String, dynamic>>());
      expect(currencies.first['code'], isA<String>());

      final categories = await api.listCategories();
      expect(
        categories.length,
        21,
        reason: 'mobilebridge/seed_defaults.go seeds 21 built-in categories',
      );

      final txns = await api.listTransactions({});
      expect(txns, isA<Map<String, dynamic>>());
      expect(txns['count'], 0);
      expect(txns['results'], isA<List>());
      expect(txns['results'], isEmpty);
      expect(txns['total_pages'], 0);
      expect(txns['current_page'], 1);
    });

    testWidgets('10.1.4 category + transaction CRUD round trip decodes', (
      tester,
    ) async {
      final created = await api.createCategory({
        'name': 'Groceries',
        'type': 'expense',
      });
      expect(created['id'], isA<int>());
      final catId = created['id'] as int;

      await api.updateCategory(catId, {'name': 'Groceries 2'});
      final cats = await api.listCategories(type: 'expense', custom: true);
      expect(cats, hasLength(1));
      expect(cats.single['name'], 'Groceries 2');

      final createResp = await api.createTransaction({
        'transaction_name': 'Coffee',
        'currency_code': 'USD',
        'transaction_type': 'expense',
        'date': DateTime.now().toUtc().toIso8601String(),
        'transaction_categories': [
          {'category_id': catId, 'amount': '4.50'},
        ],
      });
      expect(createResp['message'], 'transaction created');

      final list = await api.listTransactions({});
      expect(list['count'], 1);
      final txnId = (list['results'] as List).single['id'] as int;

      final got = await api.getTransaction(txnId);
      expect(got['name'], 'Coffee');
      expect(got['TransactionCategory'], hasLength(1));

      await api.updateTransaction(txnId, {'transaction_name': 'Coffee 2'});
      expect((await api.getTransaction(txnId))['name'], 'Coffee 2');

      await api.deleteTransaction(txnId);
      expect((await api.listTransactions({}))['count'], 0);

      await api.deleteCategory(catId);
      expect(
        (await api.listCategories(
          type: 'expense',
          custom: true,
        )),
        isEmpty,
      );
    });

    testWidgets('10.1.5 recurring transaction creates a recurrence template', (
      tester,
    ) async {
      final catId =
          (await api.listCategories(type: 'expense')).first['id'] as int;
      await api.createTransaction({
        'transaction_name': 'Netflix',
        'currency_code': 'USD',
        'transaction_type': 'expense',
        'date': DateTime.now().toUtc().toIso8601String(),
        'is_recurrent': true,
        'recurrent_freq': 'monthly',
        'transaction_categories': [
          {'category_id': catId, 'amount': '15.00'},
        ],
      });

      final recurrences = await api.listRecurrences();
      expect(recurrences, hasLength(1));
      expect(recurrences.single['name'], 'Netflix');
      expect(recurrences.single['frequency'], 'monthly');
      final recId = recurrences.single['id'] as int;

      final timeline = await api.recurrenceTimeline();
      expect(timeline, isNotEmpty);

      await api.deleteRecurrence(recId);
      expect(await api.listRecurrences(), isEmpty);
    });

    testWidgets('10.1.6 exchange rate CRUD + currency-key lookup decodes', (
      tester,
    ) async {
      await api.upsertExchangeRate(from: 'USD', to: 'EUR', rate: '0.9');
      final ratesForUsd = await api.listExchangeRates(base: 'USD');
      // GetExchangeRates filters WHERE currency_code2 = base, i.e. rates
      // *into* USD, so upserting USD->EUR (which also writes the inverse
      // EUR->USD) is what should show up when asking for base: 'USD'.
      expect(ratesForUsd, isNotEmpty);
      expect(
        ratesForUsd.any(
          (r) =>
              r['currency_code_1'] == 'EUR' && r['currency_code_2'] == 'USD',
        ),
        isTrue,
        reason: 'upsertExchangeRate writes both directions',
      );

      await expectLater(
        api.fetchExchangeRates(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.message,
            'message',
            contains('no exchange rate API key configured'),
          ),
        ),
        reason: 'setup() never sets an API key, so this must fail cleanly '
            'rather than hang on a real network call',
      );
    });
  });

  // ── 10.2 error sentinels propagate through PlatformException ───────────
  group('10.2 error sentinel propagation', () {
    testWidgets('10.2.1 not-initialized sentinel matches exactly', (
      tester,
    ) async {
      bridge.invoke('shutdown');
      await expectLater(
        api.getProfile(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.message,
            'message',
            MoneefErrors.notInitialized,
          ),
        ),
      );
    });

    testWidgets('10.2.2 already-inited sentinel matches exactly', (
      tester,
    ) async {
      // setUp already called Init via resetWithProfile().
      await expectLater(
        api.init(dbPath: bridge.dbPath, profileId: 1),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.message,
            'message',
            MoneefErrors.alreadyInited,
          ),
        ),
      );
    });

    testWidgets('10.2.3 profile-not-set sentinel matches exactly', (
      tester,
    ) async {
      bridge.reset(); // Init'd, but Setup was never called -> no profile.
      await expectLater(
        api.getProfile(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.message,
            'message',
            MoneefErrors.profileNotSet,
          ),
        ),
      );
      // Every mutating/reading call must fail the same way, not just getProfile.
      await expectLater(
        api.listTransactions({}),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.message,
            'message',
            MoneefErrors.profileNotSet,
          ),
        ),
      );
    });

    testWidgets('10.2.4 invalid JSON payload sentinel is a prefix', (
      tester,
    ) async {
      // Bypass NativeApi's jsonEncode to inject truly malformed bytes, the
      // way a corrupted payload would arrive at the Go side. bridge.invoke
      // is synchronous (raw FFI call), so it throws directly, not via Future.
      expect(
        () => bridge.invoke('createTransaction', {
          'payload': utf8.encode('{not json'),
        }),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.message ?? '',
            'message',
            contains(MoneefErrors.invalidPayload),
          ),
        ),
      );
    });

    testWidgets('10.2.5 service-level errors propagate verbatim', (
      tester,
    ) async {
      await expectLater(
        api.getTransaction(999999),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.message,
            'message',
            contains('record not found'),
          ),
        ),
        reason: 'GetTransaction wraps gorm.ErrRecordNotFound, per API.md',
      );

      await api.createCategory({'name': 'Dup', 'type': 'expense'});
      await expectLater(
        api.createCategory({'name': 'Dup', 'type': 'expense'}),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.message,
            'message',
            contains('category name already exists'),
          ),
        ),
      );

      final catId =
          (await api.listCategories(type: 'expense')).first['id'] as int;
      await expectLater(
        api.createTransaction({
          'transaction_name': 'x',
          'currency_code': 'USD',
          'transaction_type': 'expense',
          'date': DateTime.now().toUtc().toIso8601String(),
          'is_recurrent': true,
          'transaction_categories': [
            {'category_id': catId, 'amount': '1.00'},
          ],
        }),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.message,
            'message',
            contains('recurrent_freq is required'),
          ),
        ),
        reason: 'validator error from TransactionRequest.Validate()',
      );
    });
  });

  // ── 10.3 static diff: MoneefBridge.kt vs native_api.dart vs mobilebridge/*.go ─
  group('10.3 static diff across the three layers', () {
    testWidgets(
      '10.3.2 wire argument shape matches the id/payload contract per method',
      (tester) async {
        final catId = (await api.createCategory({
          'name': 'Wire',
          'type': 'expense',
        }))['id'] as int;
        bridge.calls.clear();

        // no-arg calls: neither `id` nor `payload` — matches Kotlin cases
        // that read nothing off `call` before invoking the zero-arg Go func.
        await api.listRecurrences();
        await api.recurrenceTimeline();
        await api.listCurrencies();
        await api.patterns();
        await api.getProfile();
        await api.getSettings();
        for (final c in bridge.calls) {
          expect(
            c.arguments,
            isNull,
            reason: '${c.method} must not send arguments (mobilebridge/${c.method} '
                'takes no params in Go) but sent ${c.arguments}',
          );
        }
        bridge.calls.clear();

        // id-only calls.
        await api.createTransaction({
          'transaction_name': 'Wire txn',
          'currency_code': 'USD',
          'transaction_type': 'expense',
          'date': DateTime.now().toUtc().toIso8601String(),
          'transaction_categories': [
            {'category_id': catId, 'amount': '1.00'},
          ],
        });
        final txnId =
            ((await api.listTransactions({}))['results'] as List)
                    .single['id']
                as int;
        bridge.calls.clear();
        await api.getTransaction(txnId);
        await api.deleteTransaction(txnId);
        await api.setProfileId(1);
        for (final c in bridge.calls) {
          expect(
            (c.arguments as Map).keys.toSet(),
            {'id'},
            reason: '${c.method} must send only `id`, matching '
                'MoneefBridge.kt idArg(call) / mobile.*(id int64)',
          );
        }
        bridge.calls.clear();

        // payload-only calls, including the always-send-a-body ones the
        // task flagged (e.g. listExchangeRates never omits `payload`).
        await api.createCategory({'name': 'Wire2', 'type': 'expense'});
        await api.dashboard();
        await api.listExchangeRates();
        await api.listCategories();
        for (final c in bridge.calls) {
          expect(
            (c.arguments as Map).keys.toSet(),
            {'payload'},
            reason: '${c.method} must send only `payload`',
          );
        }
      },
    );
  });

  // ── 10.4 money/decimal serialization round trip ─────────────────────────
  group('10.4 money round trip', () {
    testWidgets(
      '10.4.1 amount stays a JSON string end to end, no float artifacts',
      (tester) async {
        final catId =
            (await api.listCategories(type: 'expense')).first['id'] as int;
        // Large enough that a float64 leak would show as a precision error
        // (99999999.99 is not exactly representable in binary floating point).
        await api.createTransaction({
          'transaction_name': 'Big one',
          'currency_code': 'USD',
          'transaction_type': 'expense',
          'date': DateTime.now().toUtc().toIso8601String(),
          'transaction_categories': [
            {'category_id': catId, 'amount': '99999999.99'},
          ],
        });

        final txnId =
            ((await api.listTransactions({}))['results'] as List)
                    .single['id']
                as int;
        final got = await api.getTransaction(txnId);
        final gotAmount =
            got['TransactionCategory'][0]['amount'];
        expect(gotAmount, isA<String>());
        expect(gotAmount, '99999999.99');

        final list = await api.listTransactions({});
        final listAmount =
            (list['results'] as List).single['TransactionCategory'][0]['amount'];
        expect(listAmount, isA<String>());
        expect(listAmount, gotAmount, reason: 'get and list must agree');

        final dash = await api.dashboard();
        expect(dash['total_expense'], isA<String>());
        expect(
          dash['total_expense'],
          gotAmount,
          reason:
              'single expense of $gotAmount must equal the dashboard total',
        );
        final dashRecent = (dash['recent_transactions'] as List).single;
        expect(
          dashRecent['TransactionCategory'][0]['amount'],
          gotAmount,
          reason: 'dashboard recent_transactions must show the same amount '
              'as getTransaction/listTransactions, not a re-rounded copy',
        );
      },
    );

    testWidgets(
      '10.4.2 sub-cent input is rounded consistently, not silently divergent',
      (tester) async {
        // pkg/types/money.go Money.Scan() rounds every DB read to
        // config.AmountRounding (2dp), even though the column is
        // decimal(19,4) — a schema/behavior mismatch (see bug report).
        // What must NOT happen is different call paths disagreeing about
        // the rounded value.
        final catId =
            (await api.listCategories(type: 'expense')).first['id'] as int;
        await api.createTransaction({
          'transaction_name': 'Sub-cent',
          'currency_code': 'USD',
          'transaction_type': 'expense',
          'date': DateTime.now().toUtc().toIso8601String(),
          'transaction_categories': [
            {'category_id': catId, 'amount': '4.567'},
          ],
        });
        final txnId =
            ((await api.listTransactions({}))['results'] as List)
                    .single['id']
                as int;
        final getAmount =
            (await api.getTransaction(
                  txnId,
                ))['TransactionCategory'][0]['amount']
                as String;
        final listAmount =
            ((await api.listTransactions(
                          {},
                        ))['results']
                        as List)
                    .single['TransactionCategory'][0]['amount']
                as String;
        expect(
          getAmount,
          listAmount,
          reason: 'getTransaction and listTransactions must round the same '
              'way for the same stored value',
        );
        final dashTotal = (await api.dashboard())['total_expense'] as String;
        expect(
          dashTotal,
          getAmount,
          reason: 'dashboard total must match the (rounded) transaction '
              'amount for a single-transaction period',
        );
      },
    );
  });
}
