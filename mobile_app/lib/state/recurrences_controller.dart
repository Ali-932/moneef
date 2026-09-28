import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recurrence_template.dart';
import 'bootstrap.dart';
import 'insights_providers.dart';
import 'providers.dart';

final recurrencesProvider = FutureProvider<List<RecurrenceTemplate>>((
  ref,
) async {
  if (ref.watch(bootControllerProvider).stage != BootStage.ready) return [];
  final raw = await ref.watch(nativeApiProvider).listRecurrences();
  return raw
      .cast<Map<String, dynamic>>()
      .map(RecurrenceTemplate.fromJson)
      .toList();
});

class RecurrencesController {
  RecurrencesController(this._ref);
  final Ref _ref;

  void _refresh() {
    _ref.invalidate(recurrencesProvider);
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(analysisProvider);
    _ref.invalidate(insightsIncomeProvider);
    _ref.invalidate(recurrenceTimelineProvider);
  }

  Future<void> update(int id, Map<String, dynamic> details) async {
    await _ref.read(nativeApiProvider).updateRecurrence(id, details);
    _refresh();
  }

  Future<void> delete(int id) async {
    await _ref.read(nativeApiProvider).deleteRecurrence(id);
    _refresh();
  }
}

final recurrencesControllerProvider = Provider(RecurrencesController.new);
