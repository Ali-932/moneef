import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
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

  testWidgets('home renders against the real Go core', (tester) async {
    setGoldenSurface(tester);
    await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/home'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(bridge.callCount('dashboard'), greaterThan(0));
    final cats = bridge.json('listCategories', body: {}) as List;
    expect(cats, isNotEmpty);
  });
}
