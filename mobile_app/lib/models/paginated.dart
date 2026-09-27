import 'transaction.dart';

/// Dart mirror of `mobilebridge.PaginatedTransactions` (see `mobilebridge/transactions.go`).
/// No next/previous URLs — pagination is computed from `page` + `perPage`.
class PaginatedTransactions {
  const PaginatedTransactions({
    required this.count,
    required this.totalPages,
    required this.currentPage,
    required this.perPage,
    required this.results,
  });

  final int count;
  final int totalPages;
  final int currentPage;
  final int perPage;
  final List<Transaction> results;

  bool get hasMore => currentPage < totalPages;

  factory PaginatedTransactions.fromJson(Map<String, dynamic> json) {
    final raw = (json['results'] as List?) ?? const [];
    return PaginatedTransactions(
      count: (json['count'] as num?)?.toInt() ?? 0,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 20,
      results: raw
          .cast<Map<String, dynamic>>()
          .map(Transaction.fromJson)
          .toList(growable: false),
    );
  }

  PaginatedTransactions append(PaginatedTransactions next) {
    return PaginatedTransactions(
      count: next.count,
      totalPages: next.totalPages,
      currentPage: next.currentPage,
      perPage: next.perPage,
      results: [...results, ...next.results],
    );
  }
}
