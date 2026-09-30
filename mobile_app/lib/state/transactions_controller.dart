import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/native_api.dart';
import 'bootstrap.dart';
import 'insights_providers.dart';
import 'providers.dart';
import 'recurrences_controller.dart';

/// One category line inside a transaction draft.
class TransactionDraftCategory {
  const TransactionDraftCategory({
    required this.categoryId,
    required this.amount,
  });

  final int categoryId;
  final Decimal amount;

  Map<String, dynamic> toJson() => {
    'category_id': categoryId,
    'amount': amount.toString(),
  };
}

enum RecurrenceFrequency {
  weekly('weekly'),
  biWeekly('bi-weekly'),
  monthly('monthly'),
  yearly('yearly');

  const RecurrenceFrequency(this.value);
  final String value;
}

/// Payload for creating or updating a transaction.
class TransactionDraft {
  const TransactionDraft({
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.date,
    required this.categories,
    this.merchantName = '',
    this.notes = '',
    this.icon = '',
    this.color = '',
    this.isRecurrent = false,
    this.recurrentFreq,
    this.recurrentHasEndDate = false,
    this.recurrentEndDate,
    this.recurrentTotalAmount,
    this.recurrentPaidPreviously,
    this.accountId,
  });

  final String name;
  final String type;
  final String currencyCode;
  final DateTime date;
  final List<TransactionDraftCategory> categories;
  final String merchantName;
  final String notes;
  final String icon;
  final String color;

  final bool isRecurrent;
  final RecurrenceFrequency? recurrentFreq;
  final bool recurrentHasEndDate;
  final DateTime? recurrentEndDate;
  final Decimal? recurrentTotalAmount;
  final Decimal? recurrentPaidPreviously;

  /// Null leaves the choice to the backend: the default account on create,
  /// unchanged on edit.
  final int? accountId;

  Decimal get totalAmount =>
      categories.fold(Decimal.zero, (sum, c) => sum + c.amount);

  /// Validates the draft and returns an error message, or `null` if valid.
  String? validate() {
    if (name.trim().isEmpty) return 'Name is required';
    if (categories.isEmpty) {
      return 'Add at least one category with an amount';
    }
    final seen = <int>{};
    for (final c in categories) {
      if (c.categoryId <= 0) return 'Select a category for every row';
      if (!seen.add(c.categoryId)) return 'Duplicate category';
      if (c.amount <= Decimal.zero) return 'Amount must be greater than zero';
    }
    if (isRecurrent) {
      if (recurrentFreq == null) return 'Select a recurrence frequency';
      if (recurrentHasEndDate) {
        if (recurrentEndDate == null) return 'Select an end date';
        if (recurrentEndDate!.isBefore(date)) {
          return 'End date cannot be before transaction date';
        }
        if (recurrentTotalAmount == null ||
            recurrentTotalAmount! <= Decimal.zero) {
          return 'Total amount must be greater than zero';
        }
        if (recurrentPaidPreviously == null ||
            recurrentPaidPreviously! < Decimal.zero) {
          return 'Amount paid previously cannot be negative';
        }
        if (recurrentPaidPreviously! > recurrentTotalAmount!) {
          return 'Amount paid previously cannot exceed total amount';
        }
      }
    }
    return null;
  }

  Map<String, dynamic> toCreatePayload() {
    final body = <String, dynamic>{
      'transaction_name': name,
      'currency_code': currencyCode,
      'transaction_type': type,
      'date': date.toUtc().toIso8601String(),
      if (icon.isNotEmpty) 'icon': icon,
      if (color.isNotEmpty) 'color': color,
      if (merchantName.isNotEmpty) 'merchant_name': merchantName,
      if (notes.isNotEmpty) 'notes': notes,
      if (accountId != null) 'account_id': accountId,
      'transaction_categories': categories
          .map((c) => c.toJson())
          .toList(growable: false),
    };

    if (isRecurrent) {
      body['is_recurrent'] = true;
      body['is_active_recurrent'] = true;
      if (recurrentFreq != null) body['recurrent_freq'] = recurrentFreq!.value;
      if (recurrentHasEndDate) {
        body['recurrent_has_end_date'] = true;
        if (recurrentEndDate != null) {
          body['recurrent_end_date'] = recurrentEndDate!
              .toUtc()
              .toIso8601String();
        }
        if (recurrentTotalAmount != null) {
          body['recurrent_total_amount'] = recurrentTotalAmount.toString();
        }
        if (recurrentPaidPreviously != null) {
          body['recurrent_paid_previously'] = recurrentPaidPreviously
              .toString();
        }
      }
    }

    return body;
  }

  Map<String, dynamic> toUpdatePayload() {
    return {
      'transaction_name': name,
      'currency_code': currencyCode,
      'transaction_type': type,
      'date': date.toUtc().toIso8601String(),
      if (merchantName.isNotEmpty) 'merchant_name': merchantName,
      'notes': notes,
      if (accountId != null) 'account_id': accountId,
      'transaction_categories': categories
          .map((c) => c.toJson())
          .toList(growable: false),
    };
  }
}

class TransactionsMutationController {
  TransactionsMutationController(this._ref);
  final Ref _ref;

  NativeApi get _api => _ref.read(nativeApiProvider);

  /// Invalidates every cache that could surface this transaction so the UI
  /// re-fetches authoritative state from the Go core.
  void _invalidateAll() {
    _ref.read(transactionsListProvider.notifier).refresh();
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(usedCategoriesProvider);
    _ref.invalidate(analysisProvider);
    _ref.invalidate(insightsIncomeProvider);
    _ref.invalidate(patternsProvider);
    _ref.invalidate(recurrenceTimelineProvider);
    _ref.invalidate(recurrencesProvider);
    _ref.invalidate(accountsProvider);
    _ref.invalidate(accountActivityProvider);
  }

  Future<void> create(TransactionDraft draft) async {
    await _api.createTransaction(draft.toCreatePayload());
    _invalidateAll();
  }

  Future<void> update(int id, TransactionDraft draft) async {
    await _api.updateTransaction(id, draft.toUpdatePayload());
    _invalidateAll();
    _ref.invalidate(transactionByIdProvider(id));
  }

  Future<void> delete(int id) async {
    await _api.deleteTransaction(id);
    _invalidateAll();
  }
}

final transactionsMutationProvider = Provider<TransactionsMutationController>((
  ref,
) {
  return TransactionsMutationController(ref);
});
