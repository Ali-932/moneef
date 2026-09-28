import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/utils/errors.dart';

void main() {
  test('userMessage cleans prefixes, hides noise, keeps short messages', () {
    // Strips the Dart exception prefix.
    expect(
      userMessage(Exception('Network unreachable')),
      'Network unreachable',
    );
    // A bare short string passes through.
    expect(userMessage('Currency code is invalid'), 'Currency code is invalid');
    // Stack-shaped / multi-line / over-long blobs fall back.
    expect(
      userMessage('boom\n#0 main (file.dart:1)'),
      'Something went wrong. Please try again.',
    );
    expect(userMessage('x' * 200), 'Something went wrong. Please try again.');
  });
}
