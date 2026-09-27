import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/widgets/common/picker_field.dart';

void main() {
  testWidgets('an empty picker can create and select its first item', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickerFormField<String>(
            title: 'Category',
            placeholder: 'Select category',
            value: null,
            items: const [],
            labelBuilder: (v) => v,
            onChanged: (v) => picked = v,
            createLabel: 'Add new category',
            onCreate: () async => 'Equipment',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Select category'));
    await tester.pumpAndSettle();
    expect(find.text('No results'), findsOneWidget);
    await tester.tap(find.text('Add new category'));
    await tester.pumpAndSettle();
    expect(picked, 'Equipment');
    expect(find.text('Equipment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PickerFormField: tapping opens the sheet and picking an item '
      'updates the field and fires onChanged', (tester) async {
    String? picked;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickerFormField<String>(
            title: 'Type',
            placeholder: 'Select type',
            value: null,
            items: const ['expense', 'income'],
            labelBuilder: (v) => v == 'expense' ? 'Expense' : 'Income',
            onChanged: (v) => picked = v,
          ),
        ),
      ),
    );

    // Placeholder shown before any selection.
    expect(find.text('Select type'), findsOneWidget);

    // Open the bottom sheet.
    await tester.tap(find.text('Select type'));
    await tester.pumpAndSettle();

    // Sheet title + both options are visible.
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);

    // Pick "Income".
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    // onChanged got the raw value, and the field now shows the label.
    expect(picked, 'income');
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Select type'), findsNothing);
  });

  testWidgets('PickerFormField: nullOptionLabel lets a null selection through', (
    tester,
  ) async {
    int? picked = 7;
    var changed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickerFormField<int>(
            title: 'Category',
            placeholder: 'All categories',
            value: 7,
            items: const [1, 2],
            labelBuilder: (v) => 'Cat $v',
            nullOptionLabel: 'All categories',
            onChanged: (v) {
              picked = v;
              changed = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PickerField));
    await tester.pumpAndSettle();

    // The null option is rendered at the top of the list.
    expect(find.text('All categories'), findsWidgets);

    // Tapping it returns null and is delivered (because nullOptionLabel is set).
    await tester.tap(find.text('All categories').last);
    await tester.pumpAndSettle();

    expect(changed, isTrue);
    expect(picked, isNull);
  });
}
