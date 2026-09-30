import 'package:go_router/go_router.dart';

import 'screens/accounts_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/backups_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recurrences_screen.dart';
import 'screens/edit_recurrence_screen.dart';
import 'screens/shell.dart';
import 'screens/transaction_detail_screen.dart';
import 'screens/transactions_screen.dart';
import 'utils/page_transitions.dart';

/// Route tree, extracted from [appRouter] so tests can spin up an isolated
/// `GoRouter` per case (a shared router instance can retain stale pages
/// across unrelated navigations within one test run).
final List<RouteBase> appRoutes = [
  GoRoute(
    path: '/profile/backups',
    pageBuilder: (_, state) =>
        sharedAxisPage(key: state.pageKey, child: const BackupsScreen()),
  ),
  GoRoute(
    path: '/profile/backups/restore',
    pageBuilder: (_, state) =>
        sharedAxisPage(key: state.pageKey, child: const RestoreBackupScreen()),
  ),
  ShellRoute(
    builder: (context, state, child) => AppShell(child: child),
    routes: [
      GoRoute(
        path: '/home',
        pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen()),
      ),
      GoRoute(
        path: '/insights',
        pageBuilder: (_, __) => const NoTransitionPage(child: InsightsScreen()),
      ),
      GoRoute(
        path: '/transactions',
        pageBuilder: (_, __) =>
            const NoTransitionPage(child: TransactionsScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (_, __) => const NoTransitionPage(child: ProfileScreen()),
      ),
    ],
  ),
  GoRoute(
    path: '/add',
    pageBuilder: (_, state) => sharedAxisPage(
      key: state.pageKey,
      child: AddTransactionScreen(
        initialRecurring: state.uri.queryParameters['recurring'] == 'true',
      ),
    ),
  ),
  GoRoute(
    path: '/transactions/:id',
    pageBuilder: (_, state) => sharedAxisPage(
      key: state.pageKey,
      child: TransactionDetailScreen(
        id: int.parse(state.pathParameters['id']!),
      ),
    ),
  ),
  GoRoute(
    path: '/transactions/:id/edit',
    pageBuilder: (_, state) => sharedAxisPage(
      key: state.pageKey,
      child: AddTransactionScreen(
        initialId: int.parse(state.pathParameters['id']!),
      ),
    ),
  ),
  GoRoute(
    path: '/profile/accounts',
    pageBuilder: (_, state) =>
        sharedAxisPage(key: state.pageKey, child: const AccountsScreen()),
  ),
  GoRoute(
    path: '/profile/accounts/:id',
    pageBuilder: (_, state) => sharedAxisPage(
      key: state.pageKey,
      child: AccountScreen(id: int.parse(state.pathParameters['id']!)),
    ),
  ),
  GoRoute(
    path: '/profile/categories',
    pageBuilder: (_, state) =>
        sharedAxisPage(key: state.pageKey, child: const CategoriesScreen()),
  ),
  GoRoute(
    path: '/profile/recurrences/:id/edit',
    pageBuilder: (_, state) => sharedAxisPage(
      key: state.pageKey,
      child: EditRecurrenceScreen(id: int.parse(state.pathParameters['id']!)),
    ),
  ),
  GoRoute(
    path: '/profile/recurrences',
    pageBuilder: (_, state) =>
        sharedAxisPage(key: state.pageKey, child: const RecurrencesScreen()),
  ),
];

final appRouter = GoRouter(initialLocation: '/home', routes: appRoutes);
