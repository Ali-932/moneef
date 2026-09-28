import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/utils/format.dart';

void main() {
  test('inverseRateString shows the natural "1 base = N foreign" rate', () {
    // Stored foreign→base 0.0008 (1 IQD = 0.0008 USD) → "1 USD = 1250 IQD".
    expect(inverseRateString(Decimal.parse('0.0008')), '1250');
    // And back the other way.
    expect(inverseRateString(Decimal.parse('1250')), '0.0008');
    // Trailing zeros trimmed.
    expect(inverseRateString(Decimal.parse('0.5')), '2');
    // Guard: non-positive rate → empty (no divide-by-zero).
    expect(inverseRateString(Decimal.zero), '');
  });
}
