import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/utils/contrast.dart';

void main() {
  test('wcagForeground picks the higher-contrast pure black/white, not a theme ink', () {
    // Entertainment amber, lum 0.4963 — old code returned dark-mode's
    // near-white ink here (1.70:1). Black wins actual contrast (10.93:1).
    expect(wcagForeground(const Color(0xFFFDAA00)), Colors.black);

    // Shopping emerald, lum 0.3642 — old flat 0.4 cutoff always picked
    // white (2.54:1, fails AA). Black wins (8.28:1).
    expect(wcagForeground(const Color(0xFF00B894)), Colors.black);

    // Genuinely dark tile, lum 0.0254 — white correctly wins either way
    // (13.92:1).
    expect(wcagForeground(const Color(0xFF2B2750)), Colors.white);

    // Same bg color, no theme/ink input possible anymore: the signature
    // takes only `bg`, so the result can't vary by theme.
    const bg = Color(0xFFFDAA00);
    expect(wcagForeground(bg), wcagForeground(bg));
  });
}
