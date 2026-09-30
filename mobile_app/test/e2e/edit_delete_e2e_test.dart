// T3 View / edit / delete transaction — full flow-tree e2e coverage against
// the REAL Go core (see mobilebridge/_e2e/main.go, test/e2e/real_bridge.dart).
//
// Tree:
// T3 View / edit / delete transaction
// ├─ 3.1 Detail screen shows exactly what was stored
// ├─ 3.2 Edit via UI
// │  ├─ 3.2.1 amount
// │  ├─ 3.2.2 expense↔income switch
// │  ├─ 3.2.3 change category / add+remove splits
// │  ├─ 3.2.4 currency
// │  ├─ 3.2.5 date
// │  └─ 3.2.6 toggle recurring on/off
// └─ 3.3 Delete
//    ├─ 3.3.1 confirm → gone everywhere
//    ├─ 3.3.2 cancel → untouched
//    └─ 3.3.3 delete a recurring-linked transaction → recurrence consistency
//
// Each leaf drives the real UI (tap/enterText/pickers) then verifies through
// two independent channels: `bridge.json(...)` reads of persisted DB state,
// and the rendered widget tree.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
import 'real_bridge.dart';

Finder field(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

/// Mounts [path] as a fresh screen, always preceded by a teardown pump.
///
/// go_router derives a page's `Key` from its path, so re-pumping the SAME
/// path while the previous `Navigator` Element is still alive makes
/// Flutter's Page-based reconciliation (`Page.canUpdate`) treat it as the
/// same logical route and reuse the OLD Route's entire Element/State
/// subtree (e.g. a `FormFieldState` still holding its very first
/// `initialValue`) instead of a fresh push. A real app never hits this —
/// `pop` always disposes the old route's Element before any later push
/// recreates the screen. The teardown pump below (mount an unrelated
/// widget, settle, then mount the real one) forces Flutter to fully
/// dispose the previous tree first, so every call to this helper behaves
/// like a genuine fresh navigation — this is what "reopen the screen"
/// means throughout this file.
Future<void> pumpScreen(
  WidgetTester tester,
  String path, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  setGoldenSurface(tester);
  await tester.pumpWidget(appUnderTest(themeMode: themeMode, path: path));
  await settle(tester);
}

void main() {
  final bridge = RealBridge.instance;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bridge.resetWithProfile();
    bridge.install();
  });

  // ── helpers ────────────────────────────────────────────────────────────

  /// Category id for [name]/[type] among the 21 built-in seeded categories
  /// (see mobilebridge/seed_defaults.go) — resolved dynamically, never hardcoded,
  /// since ids are assignment order and shouldn't be assumed stable.
  int categoryId(String name, {String type = 'expense'}) {
    final cats = bridge.json('listCategories', body: {'type': type}) as List;
    final match = cats.firstWhere(
      (c) => (c as Map<String, dynamic>)['name'] == name,
      orElse: () => throw StateError('no seeded category named "$name"/$type'),
    );
    return (match as Map<String, dynamic>)['id'] as int;
  }

  /// Creates a transaction directly against the real Go core and returns
  /// its id (`CreateTransaction` itself returns no id, so this looks the
  /// freshly-created row back up).
  int createTransaction(Map<String, dynamic> body) {
    bridge.json('createTransaction', body: body);
    final list = bridge.json('listTransactions', body: {'per_page': 1}) as Map;
    return ((list['results'] as List).first as Map<String, dynamic>)['id']
        as int;
  }

  Map<String, dynamic> getTxn(int id) =>
      bridge.json('getTransaction', id: id) as Map<String, dynamic>;

  /// Selects [label] from an already-open picker bottom sheet. Filters via
  /// the sheet's own search box rather than tapping the raw list item —
  /// `showPickerBottomSheet`'s `ListView` is lazy, so an item far down an
  /// unfiltered list (categories, currencies) may not be laid out yet and a
  /// direct `find.text(label)` tap would find nothing.
  Future<void> pickFromSheet(WidgetTester tester, String label) async {
    await tester.enterText(field('Search...'), label);
    await settle(tester);
    // .last: the typed search text also renders inside the search
    // TextField's own EditableText, which `find.text` matches too — the
    // filtered list tile comes after it in the tree.
    await tester.tap(find.text(label).last);
    await settle(tester);
  }

  // A fixed noon-UTC anchor day-of-month so every test's dates fall inside
  // the current calendar month (Dashboard's default period) regardless of
  // which day this suite happens to run on.
  final now = DateTime.now();
  DateTime anchor(int day, [int hour = 12]) =>
      DateTime.utc(now.year, now.month, day, hour);

  // ── 3.1 Detail screen shows exactly what was stored ─────────────────────

  group('3.1', () {
    testWidgets(
      '3.1 detail screen shows exactly what was stored (amount, currency, '
      'splits, date, merchant, notes, type)',
      (tester) async {
        final foodId = categoryId('Food');
        final transportId = categoryId('Transport');
        final txDate = anchor(12, 9);
        final id = createTransaction({
          'transaction_name': 'Grocery run',
          'currency_code': 'EUR',
          'transaction_type': 'expense',
          'date': txDate.toIso8601String(),
          'merchant_name': 'Carrefour',
          'notes': 'Weekly shop plus batteries',
          'transaction_categories': [
            {'category_id': foodId, 'amount': '54.30'},
            {'category_id': transportId, 'amount': '12.00'},
          ],
        });

        await pumpScreen(tester, '/transactions/$id');
        expect(tester.takeException(), isNull);

        // Rendered UI reflects every stored field.
        expect(find.text('Grocery run'), findsOneWidget);
        expect(find.text(r'-€66.30'), findsOneWidget); // total, expense
        expect(find.text('Expense'), findsOneWidget);
        expect(find.text('EUR'), findsOneWidget);
        expect(find.text('Carrefour'), findsOneWidget);
        expect(find.text('Weekly shop plus batteries'), findsOneWidget);
        expect(find.text('Food'), findsOneWidget);
        expect(find.text('€54.30'), findsOneWidget);
        expect(find.text('Transport'), findsOneWidget);
        expect(find.text('€12.00'), findsOneWidget);

        // Independent DB-level verification.
        final stored = getTxn(id);
        expect(stored['name'], 'Grocery run');
        expect(stored['currency_code'], 'EUR');
        expect(stored['type'], 'expense');
        expect(stored['merchant_name'], 'Carrefour');
        expect(stored['notes'], 'Weekly shop plus batteries');
        final cats = stored['TransactionCategory'] as List;
        expect(cats, hasLength(2));
        // shopspring/decimal round-trips '54.30' as '54.3' (trailing zeros
        // dropped) — compare numerically, not as raw strings.
        expect(
          cats
              .map((c) => double.parse((c as Map)['amount'] as String))
              .toSet(),
          {54.30, 12.00},
        );
      },
    );
  });

  // ── 3.2 Edit via UI ──────────────────────────────────────────────────────

  group('3.2', () {
    testWidgets('3.2.1 edit amount', (tester) async {
      final foodId = categoryId('Food');
      final id = createTransaction({
        'transaction_name': 'Coffee',
        'currency_code': 'USD',
        'transaction_type': 'expense',
        'date': anchor(10).toIso8601String(),
        'transaction_categories': [
          {'category_id': foodId, 'amount': '4.50'},
        ],
      });

      await pumpScreen(tester, '/transactions/$id/edit');
      // shopspring/decimal round-trips '4.50' as '4.5' (trailing zero
      // dropped) — the edit form prefills from that trimmed string.
      expect(find.text('4.5'), findsOneWidget);

      await tester.enterText(field('0.00').first, '19.75');
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      final stored = getTxn(id);
      final cats = stored['TransactionCategory'] as List;
      expect(cats, hasLength(1));
      expect((cats.first as Map)['amount'], '19.75');

      // Rendered UI reflects the new amount on re-open.
      await pumpScreen(tester, '/transactions/$id');
      expect(find.text(r'-$19.75'), findsOneWidget);
    });

    testWidgets('3.2.2 expense↔income switch', (tester) async {
      final foodId = categoryId('Food');
      final salaryId = categoryId('Salary', type: 'income');
      final id = createTransaction({
        'transaction_name': 'Freelance gig',
        'currency_code': 'USD',
        'transaction_type': 'expense',
        'date': anchor(10).toIso8601String(),
        'transaction_categories': [
          {'category_id': foodId, 'amount': '30.00'},
        ],
      });

      await pumpScreen(tester, '/transactions/$id/edit');

      await tester.tap(find.text('Income'));
      await settle(tester);
      // Switching type resets the category rows (they were expense-typed).
      await tester.tap(find.text('Select category'));
      await settle(tester);
      await tester.tap(find.text('Salary'));
      await settle(tester);
      await tester.enterText(field('0.00').first, '30.00');
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      final stored = getTxn(id);
      expect(stored['type'], 'income');
      final cats = stored['TransactionCategory'] as List;
      expect(cats, hasLength(1));
      expect((cats.first as Map)['category_id'], salaryId);

      await pumpScreen(tester, '/transactions/$id');
      expect(find.text('Income'), findsOneWidget);
      expect(find.text(r'+$30.00'), findsOneWidget);
    });

    testWidgets('3.2.3 change category, then add a split, then remove one', (
      tester,
    ) async {
      final foodId = categoryId('Food');
      final transportId = categoryId('Transport');
      final utilitiesId = categoryId('Utilities');
      final id = createTransaction({
        'transaction_name': 'Mixed spend',
        'currency_code': 'USD',
        'transaction_type': 'expense',
        'date': anchor(10).toIso8601String(),
        'transaction_categories': [
          {'category_id': foodId, 'amount': '20.00'},
        ],
      });

      // Step 1: swap the single split's category Food -> Transport.
      await pumpScreen(tester, '/transactions/$id/edit');
      await tester.tap(find.text('Food'));
      await settle(tester);
      await pickFromSheet(tester, 'Transport');
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      var stored = getTxn(id);
      var cats = stored['TransactionCategory'] as List;
      expect(cats, hasLength(1));
      expect((cats.first as Map)['category_id'], transportId);

      // Step 2: reopen, add a second split (Utilities).
      await pumpScreen(tester, '/transactions/$id/edit');
      expect(find.text('Transport'), findsOneWidget); // hydrates from DB
      await tester.tap(find.text('Add category split'));
      await settle(tester);
      await tester.tap(find.text('Select category'));
      await settle(tester);
      await pickFromSheet(tester, 'Utilities');
      await tester.enterText(field('0.00').last, '8.25');
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      stored = getTxn(id);
      cats = stored['TransactionCategory'] as List;
      expect(cats, hasLength(2));
      expect(
        cats.map((c) => (c as Map)['category_id']).toSet(),
        {transportId, utilitiesId},
      );

      // Step 3: reopen, remove one split, leaving a single row.
      await pumpScreen(tester, '/transactions/$id/edit');
      await tester.tap(find.byIcon(Icons.close).first);
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      stored = getTxn(id);
      cats = stored['TransactionCategory'] as List;
      expect(cats, hasLength(1));
    });

    testWidgets('3.2.4 edit currency', (tester) async {
      final foodId = categoryId('Food');
      final id = createTransaction({
        'transaction_name': 'Hotel',
        'currency_code': 'USD',
        'transaction_type': 'expense',
        'date': anchor(10).toIso8601String(),
        'transaction_categories': [
          {'category_id': foodId, 'amount': '100.00'},
        ],
      });
      // `availableCurrenciesProvider` (mobile_app/lib/state/providers.dart:118)
      // only offers the account's own settings currency PLUS whatever has a
      // configured exchange rate — a fresh profile has none, so the picker
      // would show a single, unsearchable "USD" row and EUR would not be
      // selectable at all (see the finding filed for this). Seed a rate so
      // this leaf can actually exercise the currency-edit UI.
      bridge.json(
        'upsertExchangeRate',
        body: {'from': 'EUR', 'to': 'USD', 'rate': '1.08'},
      );

      await pumpScreen(tester, '/transactions/$id/edit');
      await tester.tap(find.text('USD'));
      await settle(tester);
      expect(find.text('Currency'), findsWidgets); // sheet open (title)
      // Only 2 currencies are offered (own settings currency + the one rate
      // just seeded above) — below the >5 threshold that shows a search
      // box, so pick the row directly.
      await tester.tap(find.text('EUR (€)'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      final stored = getTxn(id);
      expect(stored['currency_code'], 'EUR');
      // Amount is a plain field edit, not a currency conversion. (shopspring
      // round-trips '100.00' as '100' — compare numerically.)
      expect(
        double.parse(
          (((stored['TransactionCategory'] as List).first) as Map)['amount']
              as String,
        ),
        100.0,
      );

      await pumpScreen(tester, '/transactions/$id');
      expect(find.text('EUR'), findsOneWidget);
      expect(find.text(r'-€100.00'), findsOneWidget);
    });

    testWidgets(
      '3.2.4b on a fresh profile (no exchange rates configured) the '
      'currency picker offers only the account\'s own currency — every '
      'other of the 28 seeded currencies is unreachable from this screen',
      (tester) async {
        final foodId = categoryId('Food');
        final id = createTransaction({
          'transaction_name': 'Hotel',
          'currency_code': 'USD',
          'transaction_type': 'expense',
          'date': anchor(10).toIso8601String(),
          'transaction_categories': [
            {'category_id': foodId, 'amount': '100.00'},
          ],
        });

        await pumpScreen(tester, '/transactions/$id/edit');
        await tester.tap(find.text('USD'));
        await settle(tester);
        // No search box (would only appear for >5 items — see
        // showPickerBottomSheet's `_shouldShowSearch` in
        // mobile_app/lib/widgets/common/picker_field.dart), and EUR (one of
        // the 28 currencies mobilebridge/seed_defaults.go/config seeds — see
        // `listCurrencies`) is nowhere in the sheet.
        expect(find.text('Search...'), findsNothing);
        expect(find.text('EUR (€)'), findsNothing);
        expect(find.text('USD (\$)'), findsOneWidget);
      },
    );

    group('3.2.6', () {
      testWidgets(
        '3.2.6 editing a recorded transaction does not create a recurring schedule',
        (tester) async {
          final foodId = categoryId('Food');
          final id = createTransaction({
            'transaction_name': 'One-off expense',
            'currency_code': 'USD',
            'transaction_type': 'expense',
            'date': anchor(10).toIso8601String(),
            'transaction_categories': [
              {'category_id': foodId, 'amount': '9.00'},
            ],
          });

          // (a) The edit screen never renders the recurrence section — it's
          // gated on `widget.initialId == null` in AddTransactionScreen
          // (mobile_app/lib/screens/add_transaction_screen.dart).
          await pumpScreen(tester, '/transactions/$id/edit');
          expect(find.text('Recurring payment'), findsNothing);
          expect(find.text('Edit transaction'), findsOneWidget);

          // (b) Feeding recurrence fields into updateTransaction's payload
          // is silently ignored — TransactionUpdateRequest has no such
          // fields (internal/transactions/dto/handler_dto.go) — no
          // recurrence template is created.
          bridge.json(
            'updateTransaction',
            id: id,
            body: {
              'transaction_name': 'One-off expense',
              'currency_code': 'USD',
              'transaction_type': 'expense',
              'date': anchor(10).toIso8601String(),
              'transaction_categories': [
                {'category_id': foodId, 'amount': '9.00'},
              ],
              'is_recurrent': true,
              'recurrent_freq': 'monthly',
            },
          );
          final afterUpdate = getTxn(id);
          expect(afterUpdate['recurrence_template_id'], isNull);
          expect(bridge.json('listRecurrences', body: {}) as List, isEmpty);


        },
      );
    });
  });

  // ── 3.3 Delete ────────────────────────────────────────────────────────

  group('3.3', () {
    testWidgets('3.3.1 confirm delete → gone everywhere', (tester) async {
      final foodId = categoryId('Food');
      final id = createTransaction({
        'transaction_name': 'To be deleted',
        'currency_code': 'USD',
        'transaction_type': 'expense',
        'date': anchor(10).toIso8601String(),
        'transaction_categories': [
          {'category_id': foodId, 'amount': '5.00'},
        ],
      });
      // Sanity: it's actually there before deleting.
      expect(getTxn(id)['name'], 'To be deleted');

      await pumpScreen(tester, '/transactions/$id');
      await tester.tap(find.byTooltip('Delete transaction'));
      await settle(tester);
      expect(find.text('Delete transaction?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      // getTransaction now errors.
      expect(
        () => bridge.json('getTransaction', id: id),
        throwsA(isA<PlatformException>()),
      );
      // Gone from the list.
      final list =
          bridge.json('listTransactions', body: {}) as Map<String, dynamic>;
      expect(
        (list['results'] as List).any((t) => (t as Map)['id'] == id),
        isFalse,
      );
      // Gone from the home dashboard's recent-transactions feed.
      final dash = bridge.json('dashboard', body: {}) as Map<String, dynamic>;
      expect(
        (dash['recent_transactions'] as List).any(
          (t) => (t as Map)['id'] == id,
        ),
        isFalse,
      );

      // Rendered UI: transactions screen doesn't show it either.
      await pumpScreen(tester, '/transactions');
      expect(find.text('To be deleted'), findsNothing);
    });

    testWidgets('3.3.2 cancel delete → untouched', (tester) async {
      final foodId = categoryId('Food');
      final id = createTransaction({
        'transaction_name': 'Keep me',
        'currency_code': 'USD',
        'transaction_type': 'expense',
        'date': anchor(10).toIso8601String(),
        'transaction_categories': [
          {'category_id': foodId, 'amount': '5.00'},
        ],
      });

      await pumpScreen(tester, '/transactions/$id');
      await tester.tap(find.byTooltip('Delete transaction'));
      await settle(tester);
      expect(find.text('Delete transaction?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      // Still on the detail screen showing the (untouched) transaction.
      expect(find.text('Keep me'), findsOneWidget);
      final stored = getTxn(id);
      expect(stored['name'], 'Keep me');
      // shopspring/decimal round-trips '5.00' as '5' (trailing zeros
      // dropped) — compare numerically, not as a raw string.
      expect(
        double.parse(
          (stored['TransactionCategory'] as List).first['amount'] as String,
        ),
        5.0,
      );
    });

    testWidgets(
      '3.3.3 delete a recurring-linked transaction → recurrence template '
      'and timeline stay consistent',
      (tester) async {
        final foodId = categoryId('Food');
        bridge.json(
          'createTransaction',
          body: {
            'transaction_name': 'Netflix',
            'currency_code': 'USD',
            'transaction_type': 'expense',
            'date': anchor(1).toIso8601String(),
            'is_recurrent': true,
            'recurrent_freq': 'monthly',
            'is_active_recurrent': true,
            'transaction_categories': [
              {'category_id': foodId, 'amount': '15.00'},
            ],
          },
        );
        final list =
            bridge.json('listTransactions', body: {}) as Map<String, dynamic>;
        final booked =
            (list['results'] as List).first as Map<String, dynamic>;
        final txnId = booked['id'] as int;
        expect(booked['recurrence_template_id'], isNotNull);
        // GetTransactionByID (internal/transactions/repository/
        // transaction_repository.go) only Preloads "TransactionCategory.
        // Category" — never "RecurrenceTemplate" — so despite API.md
        // documenting "...and RecurrenceTemplate if any", the nested object
        // never comes back even though the FK is set (see the finding
        // filed for this; the Dart Transaction model doesn't parse the
        // field either way, so nothing downstream currently depends on it).
        expect(getTxn(txnId).containsKey('recurrence_template'), isFalse);

        final recBefore = bridge.json('listRecurrences', body: {}) as List;
        expect(recBefore, hasLength(1));
        final templateId = (recBefore.first as Map)['id'];
        final timelineBefore =
            bridge.json('recurrenceTimeline', body: {}) as List;
        expect(timelineBefore, isNotEmpty);

        await pumpScreen(tester, '/transactions/$txnId');
        await tester.tap(find.byTooltip('Delete transaction'));
        await settle(tester);
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await settle(tester);
        expect(tester.takeException(), isNull);

        // The booked instance is gone.
        expect(
          () => bridge.json('getTransaction', id: txnId),
          throwsA(isA<PlatformException>()),
        );
        // But the recurrence template survives — deleting one booked
        // instance must not cancel the underlying subscription (see
        // mobilebridge/API.md § DeleteTransaction: cascades only the
        // TransactionCategory rows + the transaction row itself).
        final recAfter = bridge.json('listRecurrences', body: {}) as List;
        expect(recAfter, hasLength(1));
        expect((recAfter.first as Map)['id'], templateId);
        final timelineAfter =
            bridge.json('recurrenceTimeline', body: {}) as List;
        expect(timelineAfter, isNotEmpty);

        // Rendered UI: Recurrences screen still lists "Netflix".
        await pumpScreen(tester, '/profile/recurrences');
        expect(find.text('Netflix'), findsOneWidget);
      },
    );
  });
}
