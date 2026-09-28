import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/utils/mdi.dart';
import 'package:mobile_app/widgets/transaction_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
import 'create_expense_e2e_test.dart'
    show field, pumpAdd, selectCategory, submit, onlyTransaction;
import 'real_bridge.dart';

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

  testWidgets(
    'first launch resolves merchant icon independently of selected category',
    (tester) async {
      await pumpAdd(tester);
      await tester.enterText(field('e.g. Morning latte'), 'Spotify Premium');
      await selectCategory(tester, 'Entertainment');
      await tester.enterText(field('0.00').first, '15');
      await submit(tester);
      expect(tester.takeException(), isNull);
      final txn = onlyTransaction(bridge);
      expect(txn['icon'], 'mdi:spotify');
      expect(txn['color'], '#1DB954');
      expect(
        (txn['TransactionCategory'] as List).first['Category']['icon'],
        'mdi:movie',
      );
      expect(
        find.descendant(
          of: find.byType(TransactionRow),
          matching: find.byIcon(mdiIconData('mdi:spotify')),
        ),
        findsOneWidget,
      );

      // The lookup dictionary and resolved transaction survive reopening.
      bridge.invoke('shutdown');
      bridge.invoke('init', {'dbPath': bridge.dbPath, 'profileId': 1});
      expect(onlyTransaction(bridge)['icon'], 'mdi:spotify');
      expect(onlyTransaction(bridge)['color'], '#1DB954');
    },
  );

  testWidgets(
    'editing a category fallback in the form applies the merchant icon',
    (tester) async {
      await pumpAdd(tester);
      await tester.enterText(field('e.g. Morning latte'), 'zzxqv 473829');
      await selectCategory(tester, 'Entertainment');
      await tester.enterText(field('0.00').first, '15');
      await submit(tester);
      final before = onlyTransaction(bridge);
      expect(before['icon'], 'mdi:movie');
      await tester.pumpWidget(
        appUnderTest(
          themeMode: ThemeMode.light,
          path: '/transactions/${before['id']}/edit',
        ),
      );
      await settle(tester);
      await tester.enterText(field('e.g. Morning latte'), 'Spotify Premium');
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      final after = onlyTransaction(bridge);
      expect(after['id'], before['id']);
      expect(after['icon'], 'mdi:spotify');
      expect(after['color'], '#1DB954');
      final oldSplit = (before['TransactionCategory'] as List).single;
      final newSplit = (after['TransactionCategory'] as List).single;
      expect(newSplit['category_id'], oldSplit['category_id']);
      expect(newSplit['amount'], oldSplit['amount']);
      expect(
        find.descendant(
          of: find.byType(TransactionRow),
          matching: find.byIcon(mdiIconData('mdi:spotify')),
        ),
        findsOneWidget,
      );
    },
  );
}
