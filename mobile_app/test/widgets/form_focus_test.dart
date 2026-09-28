import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/widgets/common/labeled_switch_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
import '../support/mutable_native_api.dart';

Finder input(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

Finder labeledInput(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

EditableText editable(WidgetTester tester, Finder finder) =>
    tester.widget<EditableText>(
      find.descendant(of: finder, matching: find.byType(EditableText)),
    );

void expectKeyboardClosed(WidgetTester tester) {
  expect(
    tester
        .widgetList<EditableText>(find.byType(EditableText))
        .any((e) => e.focusNode.hasFocus),
    isFalse,
  );
  expect(tester.testTextInput.isVisible, isFalse);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(WidgetTester tester, {String path = '/add'}) async {
    MutableNativeApi().install();
    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: path),
    );
    await settle(tester);
  }

  for (final picker in ['currency', 'category', 'date']) {
    for (final cancel in [false, true]) {
      testWidgets(
        '$picker ${cancel ? 'dismissal' : 'selection'} does not restore name focus',
        (tester) async {
          await open(tester);
          await tester.enterText(input('e.g. Morning latte'), 'Focus test');
          await settle(tester);
          expect(
            editable(tester, input('e.g. Morning latte')).focusNode.hasFocus,
            isTrue,
          );
          if (picker == 'currency') {
            await tester.tap(find.text('USD'));
          } else if (picker == 'category') {
            await tester.tap(find.text('Select category'));
          } else {
            await tester.tap(find.byIcon(Icons.calendar_today_outlined).first);
          }
          await settle(tester);
          if (cancel) {
            if (picker == 'date') {
              await tester.tap(find.text('Cancel'));
            } else {
              await tester.tapAt(const Offset(10, 100));
            }
          } else if (picker == 'date') {
            await tester.tap(find.text('Use date'));
          } else if (picker == 'currency') {
            await tester.tap(find.text(r'USD ($)'));
          } else {
            await tester.tap(find.text('Food & Dining'));
          }
          await settle(tester);
          expect(find.text('Focus test'), findsOneWidget);
          expectKeyboardClosed(tester);
        },
      );
    }
  }

  testWidgets(
    'keyboard Next follows split rows, merchant and notes after removing a split',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Add category split'));
      await settle(tester);
      await tester.enterText(input('e.g. Morning latte'), 'Split transaction');
      tester.view.viewInsets = const FakeViewPadding(bottom: 840);
      addTearDown(tester.view.resetViewInsets);
      await settle(tester);
      expect(
        editable(tester, input('e.g. Morning latte')).textInputAction,
        TextInputAction.next,
      );
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await settle(tester);
      expect(editable(tester, input('0.00').at(0)).focusNode.hasFocus, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await settle(tester);
      expect(editable(tester, input('0.00').at(1)).focusNode.hasFocus, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await settle(tester);
      expect(
        editable(tester, input('e.g. Blue Bottle')).focusNode.hasFocus,
        isTrue,
      );
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await settle(tester);
      expect(
        editable(tester, input('e.g. Team lunch')).focusNode.hasFocus,
        isTrue,
      );
      expect(
        editable(tester, input('e.g. Team lunch')).textInputAction,
        TextInputAction.newline,
      );

      await tester.ensureVisible(find.byIcon(Icons.close).first);
      await settle(tester);
      await tester.tap(find.byIcon(Icons.close).first);
      await settle(tester);
      await tester.enterText(input('0.00').first, '123');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await settle(tester);
      expect(
        editable(tester, input('e.g. Blue Bottle')).focusNode.hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile Next moves from first name to last name and Done closes keyboard',
    (tester) async {
      await open(tester, path: '/profile');
      await tester.tap(find.byTooltip('Edit profile'));
      await settle(tester);
      await tester.enterText(labeledInput('First name'), 'Alex');
      expect(
        editable(tester, labeledInput('First name')).textInputAction,
        TextInputAction.next,
      );
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await settle(tester);
      expect(
        editable(tester, labeledInput('Last name')).focusNode.hasFocus,
        isTrue,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expectKeyboardClosed(tester);
    },
  );

  testWidgets(
    'recurrence amount Next advances to paid amount; Done ends editing',
    (tester) async {
      await open(tester);
      Finder toggle(String label) => find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is LabeledSwitchRow && w.label == label,
        ),
        matching: find.byType(Switch),
      );
      for (final label in ['Recurring payment', 'Has end date?']) {
        await tester.scrollUntilVisible(
          toggle(label),
          250,
          scrollable: find
              .descendant(
                of: find.byType(Form),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await settle(tester);
        await tester.tap(toggle(label));
        await settle(tester);
      }
      await tester.ensureVisible(labeledInput('Total plan amount'));
      await settle(tester);
      await tester.enterText(labeledInput('Total plan amount'), '640000');
      expect(
        editable(tester, labeledInput('Total plan amount')).textInputAction,
        TextInputAction.next,
      );
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await settle(tester);
      expect(
        editable(
          tester,
          labeledInput('Amount already paid'),
        ).focusNode.hasFocus,
        isTrue,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expectKeyboardClosed(tester);
    },
  );

  testWidgets(
    'searching then creating a category does not revive the transaction keyboard',
    (tester) async {
      await open(tester);
      await tester.enterText(input('e.g. Morning latte'), 'Equipment');
      await tester.tap(find.text('Select category'));
      await settle(tester);
      await tester.enterText(input('Search...'), 'Workshop');
      await tester.tap(find.text('Add new category'));
      await settle(tester);
      await tester.enterText(input('Name'), 'Workshop');
      await tester.ensureVisible(find.text('Create category'));
      await settle(tester);
      await tester.tap(find.text('Create category'));
      await settle(tester);
      expect(find.text('Workshop'), findsOneWidget);
      expect(find.text('Equipment'), findsOneWidget);
      expectKeyboardClosed(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
