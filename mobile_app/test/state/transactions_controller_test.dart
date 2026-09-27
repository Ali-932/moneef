import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/analysis.dart';
import 'package:mobile_app/models/dashboard.dart';
import 'package:mobile_app/state/bootstrap.dart';
import 'package:mobile_app/state/insights_providers.dart';
import 'package:mobile_app/state/providers.dart';
import 'package:mobile_app/state/transactions_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
import '../support/mutable_native_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'create, edit and delete refresh every Home and Insights metric',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = MutableNativeApi()..install();
      final container = ProviderContainer(
        overrides: [
          bootControllerProvider.overrideWith(
            (ref) => ReadyBootController(ref.watch(nativeApiProvider)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(transactionsMutationProvider);

      Future<void> expectCurrentMetrics() async {
        final dashboard = await container.read(dashboardProvider.future);
        expect(dashboard, DashboardSummary.fromJson(api.fixtures.dashboard()));
        expect(
          await container.read(analysisProvider.future),
          AnalysisCharts.fromJson(api.fixtures.analysis()),
        );
        expect(
          await container.read(insightsIncomeProvider.future),
          dashboard.totalIncome,
        );
        await container.read(patternsProvider.future);
        await container.read(recurrenceTimelineProvider.future);
        final used = await container.read(usedCategoriesProvider.future);
        expect(
          used.map((c) => c.id),
          api.fixtures.categoriesResponse(used: true).map((c) => c['id']),
        );
      }

      TransactionDraft draft(String type, String amount) => TransactionDraft(
        name: 'New purchase',
        type: type,
        currencyCode: 'USD',
        date: api.fixtures.now,
        categories: [
          TransactionDraftCategory(
            categoryId: type == 'income' ? 13 : 1,
            amount: Decimal.parse(amount),
          ),
        ],
      );

      // Prime all caches before writing, as when a user has visited both tabs.
      await expectCurrentMetrics();
      final before = await container.read(dashboardProvider.future);
      await controller.create(draft('expense', '640000.75'));
      await expectCurrentMetrics();
      expect(
        (await container.read(dashboardProvider.future)).totalExpense,
        before.totalExpense + Decimal.parse('640000.75'),
      );

      await controller.update(
        api.lastTransactionId,
        draft('income', '700000.25'),
      );
      await expectCurrentMetrics();
      expect(
        (await container.read(dashboardProvider.future)).totalIncome,
        before.totalIncome + Decimal.parse('700000.25'),
      );
      expect(
        (await container.read(
          transactionByIdProvider(api.lastTransactionId).future,
        )).type,
        'income',
      );

      await controller.delete(api.lastTransactionId);
      await expectCurrentMetrics();
      expect(
        (await container.read(dashboardProvider.future)).balance,
        before.balance,
      );
      expect(api.calls['refreshPatterns'], 4);
      expect(api.calls['recurrenceTimeline'], 4);
      expect(
        container.read(transactionsListProvider).data!.count,
        api.fixtures.transactions.length,
      );

      // A failed save leaves the existing metrics intact.
      final calls = Map.of(api.calls);
      api.failCreate = true;
      await expectLater(
        controller.create(draft('expense', '50')),
        throwsA(isException),
      );
      await expectCurrentMetrics();
      expect(api.calls['analysis'], calls['analysis']);
      expect(api.calls['dashboard'], calls['dashboard']);
    },
  );
}
