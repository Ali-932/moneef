import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/screens/shell.dart';
import 'package:mobile_app/theme.dart';

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
      'navigation and inline add remain reachable at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            ShellRoute(
              builder: (_, __, child) => AppShell(child: child),
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (_, __) => const Text('Home content'),
                ),
                GoRoute(
                  path: '/profile',
                  builder: (_, __) => const Text('Profile content'),
                ),
              ],
            ),
            GoRoute(
              path: '/add',
              builder: (_, __) => const Scaffold(body: Text('New transaction')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: buildAppTheme(Brightness.light),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Scaffold>(find.byType(Scaffold).first)
              .floatingActionButton,
          isNull,
        );
        final add = find.byTooltip('Add transaction');
        final size = tester.getSize(add);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        expect(find.text('Profile content'), findsOneWidget);
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(find.text('New transaction'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
