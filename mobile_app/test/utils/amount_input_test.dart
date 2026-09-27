import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/utils/amount_input.dart';

TextEditingValue value(String text, [int? caret]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: caret ?? text.length),
);

void main() {
  const formatter = AmountInputFormatter();

  test('groups typing and pasted amounts without losing decimal precision', () {
    for (final entry in {
      '640000': '640,000',
      '1234567.80': '1,234,567.80',
      '640,000.00': '640,000.00',
      '12345678901234567890.123456789': '12,345,678,901,234,567,890.123456789',
      '1234.': '1,234.',
      '.5': '.5',
      '': '',
    }.entries) {
      final result = formatter.formatEditUpdate(value(''), value(entry.key));
      expect(result.text, entry.value);
      expect(result.selection.baseOffset, entry.value.length);
    }
    expect(parseAmountInput('640,000.80'), Decimal.parse('640000.80'));
    expect(parseAmountInput(''), isNull);
  });

  test('each typed digit and backspace keeps a usable caret', () {
    var current = value('');
    for (final digit in '640000'.split('')) {
      current = formatter.formatEditUpdate(
        current,
        value('${current.text}$digit'),
      );
    }
    expect(current.text, '640,000');
    while (current.text.isNotEmpty) {
      current = formatter.formatEditUpdate(
        current,
        value(current.text.substring(0, current.text.length - 1)),
      );
      expect(current.selection.baseOffset, current.text.length);
    }
  });

  test(
    'middle insertion, separator deletion and selections preserve position',
    () {
      final inserted = formatter.formatEditUpdate(
        value('640,000', 1),
        value('6940,000', 2),
      );
      expect(inserted, value('6,940,000', 3));
      expect(
        formatter.formatEditUpdate(value('1,234', 2), value('1234', 1)),
        value('234', 0),
      );
      expect(
        formatter.formatEditUpdate(value('1,234', 1), value('1234', 1)),
        value('134', 1),
      );
      final selected = formatter.formatEditUpdate(
        value(''),
        const TextEditingValue(
          text: '1234567',
          selection: TextSelection(baseOffset: 2, extentOffset: 6),
        ),
      );
      expect(selected.text, '1,234,567');
      expect(
        selected.selection,
        const TextSelection(baseOffset: 3, extentOffset: 8),
      );
    },
  );

  test('rejects malformed input and leaves IME composition untouched', () {
    for (final text in ['12.3.4', '-123', '12a', '1e3']) {
      expect(formatter.formatEditUpdate(value('12'), value(text)), value('12'));
    }
    final composing = value(
      '1234',
    ).copyWith(composing: const TextRange(start: 0, end: 4));
    expect(formatter.formatEditUpdate(value('123'), composing), composing);
  });
}
