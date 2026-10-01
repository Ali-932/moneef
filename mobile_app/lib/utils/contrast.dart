import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG 2.1 relative luminance (IEC 61966-2-1 sRGB linearisation, BT.709
/// coefficients). Color.r/g/b are [0,1] doubles on Flutter ≥3.x.
double relativeLuminance(Color c) {
  double lin(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

/// Picks whichever of pure black or white wins actual WCAG contrast ratio
/// against [bg]. Theme-independent by construction: a category's hex color
/// has nothing to do with the app's current light/dark theme, so the old
/// version's `inkColor` parameter (which flips per-theme) let a bright
/// midtone background pair with a near-white "ink" in dark mode. The
/// foreground is auto-picked by luminance instead.
Color wcagForeground(Color bg) {
  double ratio(Color fg) {
    final a = relativeLuminance(bg), b = relativeLuminance(fg);
    final hi = a > b ? a : b, lo = a > b ? b : a;
    return (hi + 0.05) / (lo + 0.05);
  }

  return ratio(Colors.black) >= ratio(Colors.white) ? Colors.black : Colors.white;
}
