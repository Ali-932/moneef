// T6 Categories (/profile/categories) — real-core e2e coverage.
//
// Flow tree under test:
// 6.1 Create: expense · income (icon, color) → list + right-type-only picker
// 6.2 Edit name / icon / color / type → persisted, reflected on transactions
// 6.3 Delete: unused · used by transactions (data loss / FK behavior)
// 6.4 Negative: duplicate name (same/different type), empty/whitespace name,
//     editing or deleting default (profile_id NULL) categories
//
// Each leaf drives the real UI (categories editor bottom sheet, and where
// relevant the add-transaction screen), then verifies independently via
// `bridge.json(...)` against the real Go core AND the rendered widget tree.
//
// Preconditions that are NOT the flow under test (e.g. "a transaction using
// this category already exists" for the delete-leaves) are seeded directly
// via `bridge.json(...)` — that calls the exact same Go service code the UI
// calls, just without re-driving the (separately-tested) add-transaction
// form for every case. ponytail: keeps each leaf focused on the categories
// flow it's named for instead of re-proving transaction creation N times.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/utils/mdi.dart';
import 'package:mobile_app/widgets/common/picker_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
import 'real_bridge.dart';

/// Same idiom as transaction_entry_test.dart: find a [TextField] (including
/// the one inside a [TextFormField]) by its hint text.
Finder field(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

/// Preset colour swatches in categories_screen.dart's `_kPresetColors`,
/// duplicated here (test-only) so a specific swatch can be targeted by its
/// rendered `BoxDecoration.color`. Index 0 (Iris, `#6c5ce7`) is the default
/// selection for a brand-new category, asserted directly where needed.
const _skyBlue = Color(0xFF0984E3); // index 3

/// A picker sheet's search box renders whatever was typed into it as its own
/// text, which collides with `find.text(name)` when searching for a result
/// by that same name. The result rows live in the sheet's `ListView`, the
/// search box does not, so scope the finder to just the results.
Finder pickerResult(String name) =>
    find.descendant(of: find.byType(ListView), matching: find.text(name));

Finder _swatch(Color c) => find.byWidgetPredicate(
  (w) =>
      w is AnimatedContainer &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).color == c,
);

void main() {
  final bridge = RealBridge.instance;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bridge.resetWithProfile(); // fresh DB, profile id 1, USD
    bridge.install();
  });

  // ── bridge-level helpers (setup + verification, not the flow under test) ──

  Map<String, dynamic> createCatViaBridge(
    String name,
    String type, {
    String icon = '',
    String color = '',
  }) {
    final body = <String, dynamic>{'name': name, 'type': type};
    if (icon.isNotEmpty) body['icon'] = icon;
    if (color.isNotEmpty) body['color'] = color;
    return bridge.json('createCategory', body: body) as Map<String, dynamic>;
  }

  List<dynamic> listCatsViaBridge([Map<String, dynamic> filter = const {}]) =>
      bridge.json('listCategories', body: filter) as List<dynamic>;

  /// Creates a transaction via the real bridge and returns its id (the
  /// create response is `{"message": ...}` per API.md — no id — so we
  /// look it up by its distinctive name straight after).
  int createTxViaBridge({
    required String name,
    required String type,
    required int categoryId,
    required String amount,
  }) {
    bridge.json(
      'createTransaction',
      body: {
        'transaction_name': name,
        'currency_code': 'USD',
        'transaction_type': type,
        'date': DateTime.now().toUtc().toIso8601String(),
        'transaction_categories': [
          {'category_id': categoryId, 'amount': amount},
        ],
      },
    );
    final found =
        bridge.json('listTransactions', body: {'search': name})
            as Map<String, dynamic>;
    final results = found['results'] as List;
    return (results.single['id'] as num).toInt();
  }

  String snackBarText(WidgetTester tester) {
    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    return (snack.content as Text).data!;
  }

  group('6.1 Create', () {
    testWidgets('6.1.1 create expense category → list + right-type picker', (
      tester,
    ) async {
      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile/categories'),
      );
      await settle(tester);

      await tester.tap(find.byTooltip('Add category'));
      await settle(tester);
      expect(find.text('New category'), findsOneWidget);

      await tester.enterText(field('Name'), 'Groceries E2E');
      // Type defaults to 'expense' — leave as-is.
      await tester.ensureVisible(find.byIcon(mdiIconData('mdi:coffee')));
      await tester.pump();
      await tester.tap(find.byIcon(mdiIconData('mdi:coffee')));
      await tester.ensureVisible(find.text('Create category'));
      await tester.pump();
      await tester.tap(find.text('Create category'));
      await settle(tester);

      // Sheet closed, back on the list, in the Expense section.
      expect(find.text('New category'), findsNothing);
      expect(find.text('Groceries E2E'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify persisted state directly.
      final cats = listCatsViaBridge();
      final created = cats.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['name'] == 'Groceries E2E',
      );
      expect(created['type'], 'expense');
      expect(created['icon'], 'mdi:coffee');
      expect(created['color'], '#6c5ce7'); // default first swatch
      expect(created['profile_id'], 1);

      // Right-type-only in the add-transaction picker: present for expense…
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/add'),
      );
      await settle(tester);
      await tester.tap(find.text('Select category'));
      await settle(tester);
      // The picker list is long (21 defaults + 1) and lazily built, so
      // search to bring the target into the built viewport.
      await tester.enterText(field('Search...'), 'Groceries E2E');
      await settle(tester);
      expect(pickerResult('Groceries E2E'), findsOneWidget);
      await tester.tapAt(const Offset(100, 50)); // dismiss via scrim
      await settle(tester);

      // …absent for income.
      await tester.tap(find.text('Income'));
      await settle(tester);
      await tester.tap(find.text('Select category'));
      await settle(tester);
      await tester.enterText(field('Search...'), 'Groceries E2E');
      await settle(tester);
      expect(pickerResult('Groceries E2E'), findsNothing);
      expect(find.text('No results'), findsOneWidget);
    });

    testWidgets('6.1.2 create income category → list + right-type picker', (
      tester,
    ) async {
      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile/categories'),
      );
      await settle(tester);

      await tester.tap(find.byTooltip('Add category'));
      await settle(tester);
      await tester.enterText(field('Name'), 'Freelance E2E');
      await tester.tap(find.text('Expense')); // open Type picker
      await settle(tester);
      await tester.tap(find.text('Income'));
      await settle(tester);
      await tester.ensureVisible(find.text('Create category'));
      await tester.pump();
      await tester.tap(find.text('Create category'));
      await settle(tester);

      // Income section sorts after the (longer) Expense section, so it isn't
      // mounted yet in the list's cache extent — scroll to it.
      await tester.scrollUntilVisible(find.text('Freelance E2E'), 300);
      expect(find.text('Freelance E2E'), findsOneWidget);
      final cats = listCatsViaBridge();
      final created = cats.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['name'] == 'Freelance E2E',
      );
      expect(created['type'], 'income');

      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/add'),
      );
      await settle(tester);
      await tester.tap(find.text('Income'));
      await settle(tester);
      await tester.tap(find.text('Select category'));
      await settle(tester);
      await tester.enterText(field('Search...'), 'Freelance E2E');
      await settle(tester);
      expect(pickerResult('Freelance E2E'), findsOneWidget);
      await tester.tapAt(const Offset(100, 50));
      await settle(tester);

      // Not offered under Expense.
      await tester.tap(find.text('Expense'));
      await settle(tester);
      await tester.tap(find.text('Select category'));
      await settle(tester);
      await tester.enterText(field('Search...'), 'Freelance E2E');
      await settle(tester);
      expect(pickerResult('Freelance E2E'), findsNothing);
    });
  });

  group('6.2 Edit', () {
    testWidgets('6.2.1 edit name → persisted, reflected on transactions', (
      tester,
    ) async {
      final cat = createCatViaBridge(
        'OldName E2E',
        'expense',
        icon: 'mdi:cart',
        color: '#0984E3',
      );
      final catId = (cat['id'] as num).toInt();
      final txId = createTxViaBridge(
        name: 'Weekly shop',
        type: 'expense',
        categoryId: catId,
        amount: '12.34',
      );

      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile/categories'),
      );
      await settle(tester);

      await tester.ensureVisible(find.text('OldName E2E'));
      await tester.pump();
      await tester.tap(find.text('OldName E2E'));
      await settle(tester);
      expect(find.text('Edit category'), findsOneWidget);
      await tester.enterText(field('Name'), 'NewName E2E');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await settle(tester);

      expect(find.text('NewName E2E'), findsOneWidget);
      expect(find.text('OldName E2E'), findsNothing);

      final cats = listCatsViaBridge();
      final updated = cats.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id'] == catId,
      );
      expect(updated['name'], 'NewName E2E');

      // Reflected on the existing transaction (join is by category_id, not a
      // denormalized copy, so this should always be current).
      final tx = bridge.json('getTransaction', id: txId) as Map<String, dynamic>;
      final txCats = tx['TransactionCategory'] as List;
      expect(
        (txCats.single['Category'] as Map)['name'],
        'NewName E2E',
      );

      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/transactions/$txId'),
      );
      await settle(tester);
      expect(find.text('NewName E2E'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6.2.2 edit icon → persisted; clearing to None clears it', (
      tester,
    ) async {
      final cat = createCatViaBridge(
        'IconTarget E2E',
        'expense',
        icon: 'mdi:cart',
        color: '#0984E3',
      );
      final catId = (cat['id'] as num).toInt();

      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile/categories'),
      );
      await settle(tester);
      await tester.ensureVisible(find.text('IconTarget E2E'));
      await tester.pump();
      await tester.tap(find.text('IconTarget E2E'));
      await settle(tester);

      // gamepad-variant (unlike e.g. mdi:gift) isn't used by any default
      // category, so the icon grid's chip is the only match on screen — the
      // categories list stays mounted behind this modal sheet and would
      // otherwise collide with a default's identical icon.
      await tester.ensureVisible(find.byIcon(mdiIconData('mdi:gamepad-variant')));
      await tester.pump();
      await tester.tap(find.byIcon(mdiIconData('mdi:gamepad-variant')));
      await tester.ensureVisible(find.text('Save changes'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await settle(tester);

      var cats = listCatsViaBridge();
      var updated = cats.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id'] == catId,
      );
      expect(updated['icon'], 'mdi:gamepad-variant', reason: 'icon change should persist');

      // Now try to clear the icon back to "None".
      await tester.ensureVisible(find.text('IconTarget E2E'));
      await tester.pump();
      await tester.tap(find.text('IconTarget E2E'));
      await settle(tester);
      await tester.ensureVisible(find.byIcon(Icons.block_outlined));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.block_outlined));
      await tester.ensureVisible(find.text('Save changes'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await settle(tester);

      cats = listCatsViaBridge();
      updated = cats.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id'] == catId,
      );
      // Expected (product intent): picking "None" and saving clears the
      // icon. Currently FAILS — BUG: categories_screen.dart's _submit()
      // only sends `icon` in the update payload when
      // `_selectedIcon.isNotEmpty` (mobile_app/lib/screens/
      // categories_screen.dart, `_CategoryEditorState._submit()`), so
      // selecting "None" is silently a no-op and the old icon survives.
      expect(
        updated['icon'],
        isNot('mdi:gamepad-variant'),
        reason: 'selecting "None" for icon should clear it, not leave the old icon',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('6.2.3 edit color → persisted', (tester) async {
      final cat = createCatViaBridge(
        'ColorTarget E2E',
        'expense',
        icon: 'mdi:cart',
        color: '#6c5ce7',
      );
      final catId = (cat['id'] as num).toInt();

      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile/categories'),
      );
      await settle(tester);
      await tester.ensureVisible(find.text('ColorTarget E2E'));
      await tester.pump();
      await tester.tap(find.text('ColorTarget E2E'));
      await settle(tester);

      await tester.ensureVisible(_swatch(_skyBlue));
      await tester.pump();
      await tester.tap(_swatch(_skyBlue));
      await tester.ensureVisible(find.text('Save changes'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await settle(tester);

      final cats = listCatsViaBridge();
      final updated = cats.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id'] == catId,
      );
      expect(updated['color'], '#0984e3');
      expect(tester.takeException(), isNull);
    });

    testWidgets('6.2.4 edit type → disabled in UI; not part of the update contract', (
      tester,
    ) async {
      final cat = createCatViaBridge('TypeTarget E2E', 'expense');
      final catId = (cat['id'] as num).toInt();

      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile/categories'),
      );
      await settle(tester);
      await tester.ensureVisible(find.text('TypeTarget E2E'));
      await tester.pump();
      await tester.tap(find.text('TypeTarget E2E'));
      await settle(tester);

      // The Type field is disabled while editing (categories_screen.dart
      // `_CategoryEditor`: `enabled: !isEdit && widget.transactionType ==
      // null`). Tapping it must not open the picker sheet.
      expect(tester.widget<PickerField>(find.byType(PickerField)).enabled, isFalse);
      await tester.tap(find.text('Expense'));
      await settle(tester);
      expect(find.text('Income'), findsNothing); // sheet did not open

      // Even bypassing the UI, UpdateCategoryRequest has no `type` field
      // (internal/categories/dto/category_dto.go) so it can't be changed.
      bridge.json('updateCategory', id: catId, body: {'type': 'income'});
      final cats = listCatsViaBridge();
      final updated = cats.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id'] == catId,
      );
      expect(updated['type'], 'expense', reason: 'type is immutable by design');
    });
  });

  group('6.3 Delete', () {
    testWidgets('6.3.1 delete unused category → removed everywhere', (
      tester,
    ) async {
      final cat = createCatViaBridge('Unused E2E', 'expense');
      final catId = (cat['id'] as num).toInt();

      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile/categories'),
      );
      await settle(tester);
      await tester.ensureVisible(find.text('Unused E2E'));
      await tester.pump();
      await tester.tap(find.text('Unused E2E'));
      await settle(tester);
      await tester.tap(find.byTooltip('Delete category'));
      await settle(tester);
      expect(find.text('Delete "Unused E2E"?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await settle(tester);

      expect(find.text('Unused E2E'), findsNothing);
      final cats = listCatsViaBridge();
      expect(
        cats.cast<Map<String, dynamic>>().where((c) => c['id'] == catId),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '6.3.2 a deleted category keeps its name on its transactions',
      (tester) async {
        final cat = createCatViaBridge('UsedByTx E2E', 'expense');
        final catId = (cat['id'] as num).toInt();
        final txId = createTxViaBridge(
          name: 'Camera lens',
          type: 'expense',
          categoryId: catId,
          amount: '250.00',
        );

        // Sanity: transaction currently carries the category + amount.
        var tx = bridge.json('getTransaction', id: txId) as Map<String, dynamic>;
        expect((tx['TransactionCategory'] as List), hasLength(1));

        setGoldenSurface(tester);
        await tester.pumpWidget(
          appUnderTest(
            themeMode: ThemeMode.light,
            path: '/profile/categories',
          ),
        );
        await settle(tester);
        await tester.ensureVisible(find.text('UsedByTx E2E'));
        await tester.pump();
        await tester.tap(find.text('UsedByTx E2E'));
        await settle(tester);
        await tester.tap(find.byTooltip('Delete category'));
        await settle(tester);
        await tester.tap(find.text('Delete'));
        await settle(tester);
        expect(tester.takeException(), isNull);

        // Deleting hides the category from lists but keeps the row, so the
        // transaction still shows it by name.
        tx = bridge.json('getTransaction', id: txId) as Map<String, dynamic>;
        final txCats = tx['TransactionCategory'] as List;
        expect(txCats, hasLength(1));
        expect(txCats.single['category_id'], catId);
        expect((txCats.single['Category'] as Map)['name'], 'UsedByTx E2E');
        final listed = bridge.json('listCategories', body: {}) as List;
        expect(listed.map((c) => c['id']), isNot(contains(catId)));

        await tester.pumpWidget(
          appUnderTest(
            themeMode: ThemeMode.light,
            path: '/transactions/$txId',
          ),
        );
        await settle(tester);
        expect(find.text('UsedByTx E2E'), findsOneWidget);
        expect(find.textContaining('250.00'), findsWidgets);
      },
    );
  });

  group('6.4 Negative', () {
    testWidgets('6.4.1 duplicate name, same type → rejected with a clean error message', (
      tester,
    ) async {
      createCatViaBridge('Rent E2E', 'expense');

      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile/categories'),
      );
      await settle(tester);
      await tester.tap(find.byTooltip('Add category'));
      await settle(tester);
      await tester.enterText(field('Name'), 'Rent E2E');
      await tester.ensureVisible(find.text('Create category'));
      await tester.pump();
      await tester.tap(find.text('Create category'));
      await settle(tester);

      // Rejected: sheet stays open, no second "Rent E2E" got created.
      expect(find.text('New category'), findsOneWidget);
      final cats = listCatsViaBridge();
      expect(
        cats.cast<Map<String, dynamic>>().where((c) => c['name'] == 'Rent E2E'),
        hasLength(1),
      );

      // BUG: userMessage() (mobile_app/lib/utils/errors.dart) only strips a
      // small set of Dart exception-type prefixes, so a PlatformException's
      // default `toString()` — "PlatformException(MOBILE_ERROR, category
      // name already exists, null, null)" — passes through untouched and is
      // shown verbatim, contradicting that file's own doc comment ("Screens
      // must never render raw exception/stack text").
      final msg = snackBarText(tester);
      expect(
        msg,
        contains('category name already exists'),
        reason: 'sanity: the real error made it to the SnackBar',
      );
      // Expected (per errors.dart's own doc comment: "Screens must never
      // render raw exception/stack text"): a clean message, no wrapper.
      // Currently FAILS — BUG: userMessage() (mobile_app/lib/utils/
      // errors.dart) only strips a small set of Dart exception-type
      // prefixes, so a PlatformException's default `toString()` —
      // "PlatformException(MOBILE_ERROR, category name already exists,
      // null, null)" — passes through untouched.
      expect(
        msg,
        isNot(contains('PlatformException')),
        reason: 'raw exception wrapper text must not leak into user-facing copy',
      );
    });

    testWidgets(
      '6.4.2 duplicate name, different type → allowed',
      (tester) async {
        createCatViaBridge('Bonus E2E', 'expense');

        // Expected (product intent, evidenced by the seeded defaults
        // themselves relying on cross-type name reuse — "Business" and
        // "Gifts" each exist as BOTH an expense and an income default in
        // mobilebridge/seed_defaults.go): an income category named the same as an
        // existing EXPENSE category should be allowed; type is the natural
        // uniqueness scope. Currently FAILS — BUG: ExistsByName
        // (internal/categories/repository/category_repository.go
        // `ExistsByName`) matches on name alone, ignoring `type`.
        Map<String, dynamic>? created;
        expect(
          () => created = createCatViaBridge('Bonus E2E', 'income'),
          returnsNormally,
          reason: 'an income category should not collide with an expense one of the same name',
        );
        expect(created?['type'], 'income');

        // Same behavior should hold through the real UI.
        createCatViaBridge('Refund E2E', 'expense');
        setGoldenSurface(tester);
        await tester.pumpWidget(
          appUnderTest(
            themeMode: ThemeMode.light,
            path: '/profile/categories',
          ),
        );
        await settle(tester);
        await tester.tap(find.byTooltip('Add category'));
        await settle(tester);
        await tester.enterText(field('Name'), 'Refund E2E');
        await tester.tap(find.text('Expense'));
        await settle(tester);
        await tester.tap(find.text('Income'));
        await settle(tester);
        await tester.ensureVisible(find.text('Create category'));
        await tester.pump();
        await tester.tap(find.text('Create category'));
        await settle(tester);

        expect(
          find.text('New category'),
          findsNothing,
          reason: 'should succeed and close the sheet, not be rejected',
        );
      },
    );

    testWidgets('6.4.3 empty/whitespace name', (tester) async {
      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile/categories'),
      );
      await settle(tester);
      await tester.tap(find.byTooltip('Add category'));
      await settle(tester);

      // Whitespace-only: client trims and blocks before ever calling the
      // bridge (categories_screen.dart _submit(): `name.isEmpty` after
      // `.trim()`).
      await tester.enterText(field('Name'), '   ');
      await tester.ensureVisible(find.text('Create category'));
      await tester.pump();
      await tester.tap(find.text('Create category'));
      await settle(tester);
      expect(find.text('New category'), findsOneWidget, reason: 'still open');
      expect(snackBarText(tester), 'Name is required');
      expect(listCatsViaBridge().cast<Map>().length, 21); // just the defaults

      // Expected (product intent — a finance app shouldn't persist a
      // blank-looking category name; the Flutter form already treats
      // whitespace-only as "Name is required"): the API layer should reject
      // or trim it too. Currently FAILS — BUG/gap: neither the mobile bridge
      // (no validator call at all in mobilebridge/categories.go, unlike the HTTP
      // handler's `validate.Struct(req)` in
      // internal/categories/category_handler.go) nor
      // CreateCategoryRequest's `required` tag (go-playground's `required`
      // only rejects the empty string, not whitespace) catches this.
      final created = createCatViaBridge('   ', 'expense');
      expect(
        (created['name'] as String).trim(),
        isNotEmpty,
        reason: 'a whitespace-only category name should be rejected or trimmed server-side',
      );
    });

    testWidgets('6.4.4 editing a default (profile_id NULL) category is blocked', (
      tester,
    ) async {
      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile/categories'),
      );
      await settle(tester);

      // "Food" is one of the 21 seeded defaults (mobilebridge/seed_defaults.go).
      await tester.ensureVisible(find.text('Food'));
      await tester.pump();
      await tester.tap(find.text('Food'));
      await settle(tester);
      expect(find.text('Edit category'), findsNothing);
      expect(
        snackBarText(tester),
        "Built-in category — can't be edited",
      );

      // No UI path exists to reach the editor for a default category, so
      // exercise the bridge contract directly.
      final cats = listCatsViaBridge();
      final food = cats.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['name'] == 'Food' && c['type'] == 'expense',
      );
      expect(food['profile_id'], isNull);
      final foodId = (food['id'] as num).toInt();

      expect(
        () => bridge.json(
          'updateCategory',
          id: foodId,
          body: {'name': 'Hacked'},
        ),
        throwsA(
          isA<Object>().having(
            (e) => e.toString(),
            'message',
            contains('record not found'),
          ),
        ),
      );
      final stillFood = listCatsViaBridge().cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id'] == foodId,
      );
      expect(stillFood['name'], 'Food');
    });

    testWidgets('6.4.5 deleting a default (profile_id NULL) category is blocked', (
      tester,
    ) async {
      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile/categories'),
      );
      await settle(tester);

      // Swipe-to-delete is disabled for defaults (categories_screen.dart:
      // `direction: c.profileId == null ? DismissDirection.none : ...`), and
      // the delete button only exists inside the editor, which never opens
      // for a default row — so there's no UI affordance to attempt this at
      // all. Confirmed by dragging the tile and finding no delete
      // confirmation dialog appears.
      await tester.ensureVisible(find.text('Food'));
      await tester.pump();
      await tester.drag(find.text('Food'), const Offset(-400, 0));
      await settle(tester);
      expect(find.textContaining('Delete "Food"'), findsNothing);

      final cats = listCatsViaBridge();
      final food = cats.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['name'] == 'Food' && c['type'] == 'expense',
      );
      final foodId = (food['id'] as num).toInt();

      expect(
        () => bridge.json('deleteCategory', id: foodId),
        throwsA(
          isA<Object>().having(
            (e) => e.toString(),
            'message',
            contains('record not found'),
          ),
        ),
      );
      expect(
        listCatsViaBridge()
            .cast<Map<String, dynamic>>()
            .where((c) => c['id'] == foodId),
        hasLength(1),
      );
    });

    testWidgets('6.4.6 renaming to an existing name is blocked', (
      tester,
    ) async {
      createCatViaBridge('Utilities E2E', 'expense');
      createCatViaBridge('Mortgage E2E', 'expense');

      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile/categories'),
      );
      await settle(tester);
      await tester.ensureVisible(find.text('Mortgage E2E'));
      await tester.pump();
      await tester.tap(find.text('Mortgage E2E'));
      await settle(tester);
      await tester.enterText(field('Name'), 'Utilities E2E');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      // Expected (product intent — CreateCategory already enforces unique
      // names per the returned "category name already exists" error, so
      // renaming should honor the same rule): at most one expense category
      // is still named "Utilities E2E". Currently FAILS — BUG:
      // service.UpdateCategory (internal/categories/service/
      // category_service.go `UpdateCategory`) never calls the
      // `ExistsByName` check that service.CreateCategory does, so the
      // rename silently succeeds and two expense categories end up sharing
      // the name.
      final dupes = listCatsViaBridge()
          .cast<Map<String, dynamic>>()
          .where((c) => c['name'] == 'Utilities E2E' && c['type'] == 'expense')
          .toList();
      expect(
        dupes,
        hasLength(1),
        reason: 'renaming to an already-taken name should be rejected, like creating one is',
      );
    });
  });
}
