import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
import 'real_bridge.dart';

void main() {
  final bridge = RealBridge.instance;

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );

  /// "account name → currency → amount" as the Go core reports it.
  Map<String, Map<String, String>> balances() => {
    for (final a in bridge.json('listAccounts') as List)
      a['name'] as String: {
        for (final b in a['balances'] as List)
          b['currency'] as String: b['amount'] as String,
      },
  };

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bridge.resetWithProfile();
    bridge.install();
  });

  testWidgets('set balance, transfer and exchange from the account page', (
    tester,
  ) async {
    bridge.json(
      'upsertExchangeRate',
      body: {'from': 'USD', 'to': 'IQD', 'rate': '1500'},
    );
    bridge.json('listAccounts'); // the Accounts list creates "Main" first
    final cash = bridge.json('createAccount', body: {'name': 'Cash'}) as Map;

    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(
        themeMode: ThemeMode.light,
        path: '/profile/accounts/${cash['id']}',
      ),
    );
    await settle(tester);

    // Cash really holds 150,000 IQD.
    await tester.tap(find.text('Set balance'));
    await settle(tester);
    await tester.tap(find.text('USD').last); // the sheet's currency picker
    await settle(tester);
    await tester.tap(find.text('IQD').last);
    await settle(tester);
    await tester.enterText(field('Actual balance'), '150000');
    await tester.tap(find.widgetWithText(FilledButton, 'Set balance'));
    await settle(tester);
    expect(balances()['Cash'], {'IQD': '150000'});
    expect(find.text('≈ \$100.00'), findsOneWidget);
    expect(find.text('Balance correction'), findsOneWidget);

    // Move 50,000 IQD into Main; it stays IQD.
    await tester.tap(find.text('Transfer').first);
    await settle(tester);
    await tester.enterText(field('Amount'), '50000');
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer').last);
    await settle(tester);
    expect(balances()['Cash'], {'IQD': '100000'});
    expect(balances()['Main'], {'IQD': '50000'});
    expect(find.text('To Main'), findsOneWidget);

    // Change 30,000 IQD into $20 inside Cash, from the ⋯ menu.
    await tester.tap(find.byTooltip('Account actions'));
    await settle(tester);
    await tester.tap(find.text('Exchange currency'));
    await settle(tester);
    await tester.enterText(field('You give'), '30000');
    await tester.enterText(field('You get'), '20');
    await tester.tap(find.widgetWithText(FilledButton, 'Exchange'));
    await settle(tester);
    expect(balances()['Cash'], {'IQD': '70000', 'USD': '20'});
    expect(find.text('Exchange'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
