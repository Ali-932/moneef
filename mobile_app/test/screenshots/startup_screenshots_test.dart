@Tags(['screenshots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/theme.dart';
import 'package:mobile_app/widgets/branding/startup_splash.dart';

import 'harness.dart';

void main() {
  setUpAll(loadRealFonts);
  for (final brightness in Brightness.values) {
    testWidgets('startup ${brightness.name}', (tester) async {
      setGoldenSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(brightness),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: StartupSplash(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/startup_${brightness.name}.png'),
      );
    });
  }
}
