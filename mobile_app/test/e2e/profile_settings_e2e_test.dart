// E2E coverage for T8 Profile & settings (/profile), driven against the
// real Go core via RealBridge (see test/e2e/real_bridge.dart). One
// testWidgets per tree leaf (8.1..8.5); each drives the real UI, then
// verifies independently via bridge.json(...) (persisted DB/settings state)
// and the rendered widget tree.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/backups_screen.dart';
import 'package:mobile_app/screens/categories_screen.dart';
import 'package:mobile_app/screens/profile_screen.dart';
import 'package:mobile_app/screens/recurrences_screen.dart';
import 'package:mobile_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
import 'real_bridge.dart';

Finder _labeled(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

// ProfileScreen's body is a plain `ListView(children: [...])`: Flutter still
// builds it as a lazy sliver, so cards past the viewport + cache extent
// (the Currencies card, last of five) have no Element/RenderObject at all
// until scrolled into view — `find.text(...)` finds nothing for them, and
// `ensureVisible` can't help since it needs the target to already exist.
// Jump the vertical Scrollable directly instead of dragging incrementally.
Future<void> _scrollProfileTo(
  WidgetTester tester, {
  required bool bottom,
}) async {
  final scrollable = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );
  final state = tester.state<ScrollableState>(scrollable);
  state.position.jumpTo(bottom ? state.position.maxScrollExtent : 0);
  await tester.pump();
}

void main() {
  final bridge = RealBridge.instance;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bridge.resetWithProfile(); // fresh DB, profile id 1, currency USD.
    bridge.install();
  });

  // 8.1 Edit name → persisted (getProfile) and shown on home
  testWidgets('8.1 edit name persists via getProfile; profile card updates', (
    tester,
  ) async {
    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: '/profile'),
    );
    await settle(tester);

    // Baseline from resetWithProfile(): first_name 'E2E', last_name 'Tester'.
    expect(find.text('E2E Tester'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit profile'));
    await settle(tester);
    await tester.enterText(_labeled('First name'), 'Alison');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    expect(find.text('Saved'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final profile = bridge.json('getProfile') as Map<String, dynamic>;
    expect(profile['first_name'], 'Alison');
    expect(profile['last_name'], 'Tester');
    expect(find.text('Alison Tester'), findsOneWidget);

    // "shown on home": grep confirms `profileProvider` / first_name is
    // referenced ONLY in profile_screen.dart — HomeScreen has no name/
    // greeting element at all (lib/screens/home_screen.dart has zero
    // references to profileProvider). This is a UI path that does not
    // exist, so we document the gap instead of asserting a nonexistent
    // widget: navigate home and confirm no such text appears anywhere.
    await tester.tap(find.text('Home'));
    await settle(tester);
    expect(find.textContaining('Alison'), findsNothing);
  });

  // 8.2 Change default currency → getSettings updated; home totals/labels
  // and add-transaction default currency follow
  testWidgets('8.2 change default currency updates settings + home; '
      'add-transaction default currency follows', (tester) async {
    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: '/profile'),
    );
    await settle(tester);

    // The default-currency picker is gated to `availableCurrenciesProvider`
    // (base + currencies with an exchange rate) — EUR must be added first,
    // exactly as a real user navigating Settings would. The Currencies card
    // is last on the page (below the initial viewport + cache extent), so
    // scroll it into view first — see `_scrollProfileTo`.
    await _scrollProfileTo(tester, bottom: true);
    await settle(tester);
    await tester.tap(find.text('Add'));
    await settle(tester);
    await tester.tap(find.text('Select currency'));
    await settle(tester);
    await tester.tap(find.text('EUR — Euro'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, '0.5');
    await tester.tap(find.widgetWithText(FilledButton, 'Add currency'));
    await settle(tester);
    expect((bridge.json('listExchangeRates', body: {}) as List), hasLength(1));

    // Change the default currency to EUR (Preferences card, near the top).
    await _scrollProfileTo(tester, bottom: false);
    await settle(tester);
    await tester.tap(find.text('USD'));
    await settle(tester);
    await tester.tap(find.text('EUR').last);
    await settle(tester);
    expect(find.text('Saved'), findsWidgets);
    expect(tester.takeException(), isNull);

    final settings = bridge.json('getSettings') as Map<String, dynamic>;
    expect(settings['currency_code'], 'EUR');

    // Home totals/labels follow the new default currency.
    await tester.tap(find.text('Home'));
    await settle(tester);
    final dash = bridge.json('dashboard', body: {}) as Map<String, dynamic>;
    expect(dash['currency_code'], 'EUR');
    expect(find.textContaining('€'), findsWidgets); // formatMoney(_, 'EUR')
    expect(find.textContaining(r'$'), findsNothing);

    // A new expense starts in the new default currency. The chip's label
    // merges with its text child, hence the prefix match.
    await tester.tap(find.byTooltip('Add transaction'));
    await settle(tester);
    expect(
      find.bySemanticsLabel(RegExp(r'^Currency: EUR\. Tap to change\.')),
      findsOneWidget,
    );
  });

  // 8.3 Dark mode toggle → theme changes + persisted (SharedPreferences +
  // settings)
  testWidgets('8.3 dark mode toggle persists to settings + SharedPreferences '
      'and flips themeModeProvider', (tester) async {
    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: '/profile'),
    );
    await settle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProfileScreen)),
    );
    expect((bridge.json('getSettings') as Map)['is_dark_mode'], isFalse);
    expect(container.read(themeModeProvider), ThemeMode.light);

    await tester.tap(find.byType(Switch));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect((bridge.json('getSettings') as Map)['is_dark_mode'], isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    // themeModeProvider is exactly what the real app (lib/main.dart:31,
    // `ref.watch(themeModeProvider)`) feeds MaterialApp.router's
    // `themeMode:` — it has flipped, confirming the settings→theme wiring.
    expect(container.read(themeModeProvider), ThemeMode.dark);

    // Persisted so a cold start paints the right theme before settings
    // reload (lib/state/providers.dart:78-80, darkModeCacheKey).
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(darkModeCacheKey), isTrue);

    // NOTE (harness limitation, not an app bug): test/screenshots/
    // harness.dart's appUnderTest() passes `themeMode` as a fixed
    // constructor argument instead of watching themeModeProvider the way
    // the real MoneefApp does — so the rendered Theme.of(context).brightness
    // cannot change within this harness no matter what the provider says.
    // themeModeProvider's value (asserted above) is the correct substitute
    // signal, and rules forbid editing harness.dart to fix this.

    // Toggle back off and confirm it round-trips.
    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect((bridge.json('getSettings') as Map)['is_dark_mode'], isFalse);
    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  // 8.4 Exchange rates: manual upsert via UI · list · fetch (no network/API
  // key → error surfaced gracefully, no crash/hang)
  testWidgets('8.4 exchange rates: manual upsert (add + edit), list, '
      'and fetch without an API key errors gracefully', (tester) async {
    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: '/profile'),
    );
    await settle(tester);
    // Currencies card is last on the page — scroll it into view first (see
    // `_scrollProfileTo`; a plain ListView still lazily builds far items).
    await _scrollProfileTo(tester, bottom: true);
    await settle(tester);

    expect(find.textContaining('No currencies added yet'), findsOneWidget);

    // Manual upsert via "Add currency".
    await tester.tap(find.text('Add'));
    await settle(tester);
    await tester.tap(find.text('Select currency'));
    await settle(tester);
    await tester.tap(find.text('EUR — Euro'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, '0.5');
    await tester.tap(find.widgetWithText(FilledButton, 'Add currency'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    // List: DB and UI agree. Upsert stores from=USD,to=EUR,rate=0.5 plus
    // its inverse (currencies.UpsertExchangeRate, mobilebridge/exchange_rates.go);
    // ListExchangeRates(base=USD) returns the EUR→USD row, rate=1/0.5=2,
    // and the settings row shows the inverse of THAT (0.5) again — a clean
    // round trip for this input.
    var rates = bridge.json('listExchangeRates', body: {}) as List;
    expect(rates, hasLength(1));
    expect(rates.first['currency_code_1'], 'EUR');
    expect(rates.first['currency_code_2'], 'USD');
    expect(Decimal.parse('${rates.first['rate']}'), Decimal.parse('2'));
    expect(find.text('EUR'), findsOneWidget);
    expect(find.text('0.5'), findsOneWidget);

    // Manual upsert via inline edit (check icon) on the existing row.
    await tester.enterText(find.byType(TextField).last, '0.25');
    await tester.tap(find.byIcon(Icons.check));
    await settle(tester);
    expect(tester.takeException(), isNull);
    rates = bridge.json('listExchangeRates', body: {}) as List;
    expect(Decimal.parse('${rates.first['rate']}'), Decimal.parse('4'));
    expect(find.text('0.25'), findsOneWidget);

    // Let the inline edit's "Saved" SnackBar finish (default 4s duration) —
    // ScaffoldMessenger queues SnackBars, so triggering the fetch error
    // below while "Saved" is still showing would just queue it behind, and
    // `find.byType(SnackBar)` would read the wrong (stale) message.
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(find.byType(SnackBar), findsNothing);

    // Fetch with no API key configured (fresh profile default:
    // exchange_rate_api_key == ''): mobilebridge/exchange_rates.go:89
    // FetchExchangeRates returns a sentinel error before any network call,
    // so this must be fast, must not crash, and must not hang.
    expect((bridge.json('getSettings') as Map)['exchange_rate_api_key'], '');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Update rates now'));
    await settle(tester);
    expect(tester.takeException(), isNull); // no crash/hang

    final snackbar = tester.widget<SnackBar>(find.byType(SnackBar));
    final message = (snackbar.content as Text).data!;
    // Error IS surfaced (no silent failure) — good.
    expect(message, isNotEmpty);
    // But NOT gracefully: lib/utils/errors.dart userMessage() only strips
    // 'Exception:'/'Error:'/'StateError:'/'FormatException:'/'_Exception:'
    // prefixes and otherwise falls back to `error.toString()`. The caught
    // error here is a PlatformException (real_bridge.dart throws
    // `PlatformException(code: 'MOBILE_ERROR', message: ...)` on any Go
    // error, mirroring the real Android bridge), whose toString() is
    // "PlatformException(MOBILE_ERROR, no exchange rate API key
    // configured, null, null)" — untouched by any of those prefixes, under
    // the 140-char cutoff, so it renders verbatim. This directly
    // contradicts userMessage()'s own doc comment ("a finance app should
    // stay calm and trustworthy, not leak `Exception: ...` blobs at the
    // user"). Contrast lib/screens/backups_screen.dart:15 `_error()`,
    // which correctly special-cases PlatformException and unwraps
    // `.message`. Confirmed app bug; assertion left failing.
    expect(
      message,
      isNot(contains('PlatformException')),
      reason:
          'BUG: userMessage() (lib/utils/errors.dart) leaks the raw '
          'PlatformException wrapper instead of a clean message: "$message"',
    );
  });

  // 8.5 Navigation to categories / recurrences / backups and back
  testWidgets('8.5 navigate to categories, recurrences, and backups and back', (
    tester,
  ) async {
    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: '/profile'),
    );
    await settle(tester);

    await tester.tap(find.text('Categories'));
    await settle(tester);
    expect(find.byType(CategoriesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await settle(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.tap(find.text('Recurring payments'));
    await settle(tester);
    expect(find.byType(RecurrencesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await settle(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.tap(find.text('Local backups'));
    await settle(tester);
    expect(find.byType(BackupsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    // real_bridge.dart stubs the `moneef/backups` channel's status as
    // {supported: false, ...} (no native plugin under test) — the screen
    // handles that path explicitly (backups_screen.dart: `!status.supported`).
    expect(
      find.text('Local backups are available in the Android app.'),
      findsOneWidget,
    );
    await tester.pageBack();
    await settle(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
