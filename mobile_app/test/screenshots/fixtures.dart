// Realistic canned JSON for every `moneef/api` MethodChannel call, built once
// per test run from the real clock so date-relative UI ("Today", chart axis
// labels, day groups) always looks sensible regardless of when the harness
// runs. Shapes mirror `mobilebridge/API.md` — money is decimal-as-string, dates are
// RFC3339 UTC.
//
// ponytail: hand-authored data instead of a fixture-generation DSL — this is
// a one-off design-screenshot harness, not a fuzzing tool.
library;

import 'dart:convert';
import 'dart:typed_data';

Uint8List jsonBytes(Object? value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));

Map<String, dynamic> _cat(
  int id,
  String name,
  String type,
  String icon,
  String color, {
  int? profileId,
}) => {
  'id': id,
  'profile_id': profileId,
  'name': name,
  'type': type,
  'icon': icon,
  'color': color,
};

Map<String, dynamic> _txCat(
  int id,
  Map<String, dynamic> category,
  String amount,
) => {
  'id': id,
  'transaction_id': 0,
  'category_id': category['id'],
  'Category': category,
  'amount': amount,
};

/// Builds and holds every fixture the screenshot harness needs. Construct
/// once per test file (`late final fixtures = Fixtures();`) — everything is
/// derived from [now] so it stays internally consistent.
class Fixtures {
  Fixtures({bool recurringIncome = false}) : now = DateTime.now() {
    _buildCategories();
    _buildTransactions();
    _buildCurrenciesAndRates();
    _buildRecurrences(includeIncome: recurringIncome);
    _buildPatterns();
    profile = {
      'id': 1,
      'first_name': 'Yusuf',
      'last_name': 'Ibrahim',
      'email': 'yusuf@example.com',
      'birthday': DateTime.utc(1995, 3, 12).toIso8601String(),
    };
    settings = {
      'currency_code': 'USD',
      'language': 'en',
      'is_notification_enabled': true,
      'is_dark_mode': false,
      'exchange_rate_api_key': '',
    };
  }

  final DateTime now;

  /// Mixed currencies and Arabic names reproduce the recurring list on a phone.
  factory Fixtures.recurringPaymentsReview() {
    final fixtures = Fixtures(recurringIncome: true);
    final income = fixtures.recurrences.first;
    final expense = fixtures.recurrences[2];
    final paused = fixtures.recurrences.last;
    fixtures.recurrences
      ..clear()
      ..addAll([
        {
          ...expense,
          'name': 'Rent',
          'currency_code': 'IQD',
          'next_payment_amount': '500000.00',
          'next_date': DateTime.utc(2026, 10, 2).toIso8601String(),
        },
        {
          ...income,
          'id': 6,
          'name': 'Monthly salary',
          'next_payment_amount': '1500.00',
          'next_date': DateTime.utc(2026, 10, 5).toIso8601String(),
        },
        {
          ...income,
          'id': 7,
          'name': 'Performance bonus',
          'currency_code': 'IQD',
          'next_payment_amount': '600000.00',
          'next_date': DateTime.utc(2026, 10, 11).toIso8601String(),
        },
        {
          ...income,
          'id': 8,
          'name': 'Salary',
          'currency_code': 'IQD',
          'next_payment_amount': '623000.00',
          'next_date': DateTime.utc(2026, 10, 26).toIso8601String(),
        },
        paused,
      ]);
    return fixtures;
  }

  late final List<Map<String, dynamic>> categories;
  late final Map<String, Map<String, dynamic>> _categoryByKey;
  late final List<Map<String, dynamic>> transactions;
  late final int multiCategoryTransactionId;
  late final List<Map<String, dynamic>> currencies;
  late final List<Map<String, dynamic>> exchangeRates;
  late final List<Map<String, dynamic>> recurrences;
  late final List<Map<String, dynamic>> recurrenceTimeline;
  late final List<Map<String, dynamic>> patterns;
  late final Map<String, dynamic> profile;
  late final Map<String, dynamic> settings;

  DateTime _at(int daysAgo, {int hour = 12, int minute = 0}) {
    final day = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysAgo));
    return DateTime.utc(day.year, day.month, day.day, hour, minute);
  }

  void _buildCategories() {
    _categoryByKey = {
      'food': _cat(1, 'Food & Dining', 'expense', 'mdi:silverware-fork-knife',
          '#FF6B6B'),
      'groceries': _cat(2, 'Groceries', 'expense', 'mdi:cart', '#1F8A3F'),
      'transport': _cat(3, 'Transport', 'expense', 'mdi:car', '#0984E3'),
      'housing': _cat(4, 'Rent & Housing', 'expense', 'mdi:home', '#8E44AD'),
      'entertainment': _cat(5, 'Entertainment', 'expense', 'mdi:movie',
          '#FDAA00', profileId: 1),
      'health': _cat(6, 'Health', 'expense', 'mdi:hospital-box', '#D9304B'),
      'shopping':
          _cat(7, 'Shopping', 'expense', 'mdi:basket', '#00B894', profileId: 1),
      'coffee':
          _cat(8, 'Coffee', 'expense', 'mdi:coffee', '#6D4C41', profileId: 1),
      'travel': _cat(9, 'Travel', 'expense', 'mdi:airplane', '#0984E3',
          profileId: 1),
      'bills': _cat(10, 'Bills & Utilities', 'expense', 'mdi:cellphone',
          '#546E7A'),
      'fitness': _cat(11, 'Fitness', 'expense', 'mdi:dumbbell', '#00CEC9',
          profileId: 1),
      'pets': _cat(12, 'Pets', 'expense', 'mdi:paw', '#6C5CE7', profileId: 1),
      'salary': _cat(13, 'Salary', 'income', 'mdi:briefcase', '#1F8A3F'),
      'freelance':
          _cat(14, 'Freelance', 'income', 'mdi:cash', '#00B894', profileId: 1),
      'gifts':
          _cat(15, 'Gifts', 'income', 'mdi:gift', '#8E44AD', profileId: 1),
    };
    categories = _categoryByKey.values.toList();
  }

  void _buildTransactions() {
    var nextTxCatId = 1;
    var nextTxId = 1;
    final list = <Map<String, dynamic>>[];

    Map<String, dynamic> tx({
      required int daysAgo,
      required String name,
      required String type,
      required List<(String, String)> splits,
      String merchant = '',
      String notes = '',
      int hour = 12,
      int minute = 0,
    }) {
      final id = nextTxId++;
      final date = _at(daysAgo, hour: hour, minute: minute);
      final txCats = [
        for (final (key, amount) in splits)
          _txCat(nextTxCatId++, _categoryByKey[key]!, amount),
      ];
      final primary = _categoryByKey[splits.first.$1]!;
      final iso = date.toIso8601String();
      return {
        'id': id,
        'created_at': iso,
        'updated_at': iso,
        'profile_id': 1,
        'name': name,
        'type': type,
        'date': iso,
        'currency_code': 'USD',
        'icon': primary['icon'],
        'color': primary['color'],
        'merchant_name': merchant,
        'notes': notes,
        'TransactionCategory': txCats,
      };
    }

    list.add(tx(
      daysAgo: 0,
      name: 'Morning Latte',
      type: 'expense',
      merchant: 'Blue Bottle Coffee',
      splits: const [('coffee', '4.50')],
      hour: 8,
      minute: 15,
    ));
    list.add(tx(
      daysAgo: 0,
      name: 'Grocery Run',
      type: 'expense',
      merchant: 'Whole Foods Market',
      notes: 'Weekly shop',
      splits: const [('groceries', '86.40')],
      hour: 18,
      minute: 5,
    ));
    list.add(tx(
      daysAgo: 1,
      name: 'Uber to Downtown',
      type: 'expense',
      merchant: 'Uber',
      splits: const [('transport', '18.75')],
      hour: 9,
      minute: 30,
    ));
    final multiIdx = list.length;
    list.add(tx(
      daysAgo: 2,
      name: 'Costco Warehouse',
      type: 'expense',
      merchant: 'Costco',
      notes: 'Household + pantry restock',
      splits: const [('groceries', '120.00'), ('shopping', '45.30')],
      hour: 14,
    ));
    multiCategoryTransactionId = list[multiIdx]['id'] as int;
    list.add(tx(
      daysAgo: 3,
      name: 'Netflix Subscription',
      type: 'expense',
      merchant: 'Netflix',
      notes: 'Monthly plan',
      splits: const [('entertainment', '15.99')],
      hour: 0,
      minute: 1,
    ));
    list.add(tx(
      daysAgo: 4,
      name: 'Salary — This Month',
      type: 'income',
      merchant: 'Acme Corp',
      notes: 'Monthly payroll',
      splits: const [('salary', '4200.00')],
      hour: 9,
    ));
    list.add(tx(
      daysAgo: 4,
      name: 'Pharmacy Pickup',
      type: 'expense',
      merchant: 'CVS Pharmacy',
      notes: 'Allergy meds',
      splits: const [('health', '23.15')],
      hour: 17,
      minute: 40,
    ));
    list.add(tx(
      daysAgo: 5,
      name: 'Gym Membership',
      type: 'expense',
      merchant: 'Anytime Fitness',
      splits: const [('fitness', '39.99')],
      hour: 7,
    ));
    list.add(tx(
      daysAgo: 6,
      name: 'Team Lunch',
      type: 'expense',
      merchant: 'Chipotle',
      notes: 'With the eng team',
      splits: const [('food', '54.20')],
      hour: 12,
      minute: 45,
    ));
    list.add(tx(
      daysAgo: 7,
      name: 'Flight to Chicago',
      type: 'expense',
      merchant: 'United Airlines',
      notes: 'Conference trip',
      splits: const [('travel', '412.60')],
      hour: 6,
    ));
    list.add(tx(
      daysAgo: 8,
      name: 'Dog Food & Treats',
      type: 'expense',
      merchant: 'Petco',
      splits: const [('pets', '58.40')],
      hour: 11,
      minute: 20,
    ));
    list.add(tx(
      daysAgo: 9,
      name: 'Freelance Design Project',
      type: 'income',
      merchant: 'Studio Nine',
      notes: 'Landing page redesign',
      splits: const [('freelance', '850.00')],
      hour: 15,
    ));
    list.add(tx(
      daysAgo: 10,
      name: 'Electric Bill',
      type: 'expense',
      merchant: 'City Power & Light',
      splits: const [('bills', '142.30')],
      hour: 10,
    ));
    list.add(tx(
      daysAgo: 11,
      name: 'New Headphones',
      type: 'expense',
      merchant: 'Best Buy',
      splits: const [('shopping', '189.99')],
      hour: 16,
      minute: 10,
    ));
    list.add(tx(
      daysAgo: 12,
      name: 'Sunday Brunch',
      type: 'expense',
      merchant: 'The Farmhouse',
      notes: 'Birthday brunch',
      splits: const [('food', '76.80'), ('entertainment', '20.00')],
      hour: 11,
      minute: 30,
    ));
    list.add(tx(
      daysAgo: 14,
      name: 'Rent — This Month',
      type: 'expense',
      merchant: 'Maple Ridge Apartments',
      splits: const [('housing', '1450.00')],
      hour: 0,
      minute: 5,
    ));
    list.add(tx(
      daysAgo: 15,
      name: 'Movie Night',
      type: 'expense',
      merchant: 'AMC Theatres',
      splits: const [('entertainment', '32.00')],
      hour: 20,
      minute: 15,
    ));
    list.add(tx(
      daysAgo: 17,
      name: 'Birthday Gift',
      type: 'expense',
      merchant: 'Amazon',
      notes: 'For mom',
      splits: const [('gifts', '65.00')],
      hour: 13,
    ));
    list.add(tx(
      daysAgo: 19,
      name: 'Weekly Groceries',
      type: 'expense',
      merchant: "Trader Joe's",
      splits: const [('groceries', '64.75')],
      hour: 18,
      minute: 50,
    ));
    list.add(tx(
      daysAgo: 21,
      name: 'Gas Station Fill-up',
      type: 'expense',
      merchant: 'Shell',
      splits: const [('transport', '48.20')],
      hour: 8,
      minute: 5,
    ));
    list.add(tx(
      daysAgo: 24,
      name: 'Coffee with Sam',
      type: 'expense',
      merchant: 'Blue Bottle Coffee',
      notes: 'Catch-up',
      splits: const [('coffee', '8.20')],
      hour: 9,
      minute: 10,
    ));
    list.add(tx(
      daysAgo: 28,
      name: 'Spotify Premium',
      type: 'expense',
      merchant: 'Spotify',
      splits: const [('entertainment', '11.99')],
      hour: 0,
      minute: 1,
    ));
    list.add(tx(
      daysAgo: 33,
      name: 'Salary — Last Month',
      type: 'income',
      merchant: 'Acme Corp',
      notes: 'Monthly payroll',
      splits: const [('salary', '4200.00')],
      hour: 9,
    ));
    list.add(tx(
      daysAgo: 40,
      name: 'Dentist Visit',
      type: 'expense',
      merchant: 'Bright Smile Dental',
      notes: 'Cleaning + checkup',
      splits: const [('health', '210.00')],
      hour: 14,
      minute: 30,
    ));
    list.add(tx(
      daysAgo: 52,
      name: 'Concert Tickets',
      type: 'expense',
      merchant: 'Ticketmaster',
      notes: 'Anniversary gift',
      splits: const [('gifts', '150.00'), ('entertainment', '90.00')],
      hour: 19,
    ));

    transactions = list;
  }

  void _buildCurrenciesAndRates() {
    currencies = const [
      {'code': 'USD', 'name': 'US Dollar', 'symbol': r'$'},
      {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
      {'code': 'GBP', 'name': 'British Pound', 'symbol': '£'},
      {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
      {'code': 'IQD', 'name': 'Iraqi Dinar', 'symbol': 'IQD'},
      {'code': 'SAR', 'name': 'Saudi Riyal', 'symbol': 'SAR'},
      {'code': 'AED', 'name': 'UAE Dirham', 'symbol': 'AED'},
    ];
    final updated = now.toUtc().toIso8601String();
    exchangeRates = [
      {
        'id': 1,
        'currency_code_1': 'EUR',
        'currency_code_2': 'USD',
        'rate': '1.08',
        'last_updated': updated,
      },
      {
        'id': 2,
        'currency_code_1': 'GBP',
        'currency_code_2': 'USD',
        'rate': '1.27',
        'last_updated': updated,
      },
      {
        'id': 3,
        'currency_code_1': 'IQD',
        'currency_code_2': 'USD',
        'rate': '0.00076',
        'last_updated': updated,
      },
    ];
  }

  void _buildRecurrences({required bool includeIncome}) {
    Map<String, dynamic> template({
      required int id,
      required String name,
      required String frequency,
      required String nextPaymentAmount,
      required int nextInDays,
      required bool isActive,
      required String catKey,
    }) {
      final cat = _categoryByKey[catKey]!;
      return {
        'id': id,
        'profile_id': 1,
        'name': name,
        'type': cat['type'],
        'currency_code': 'USD',
        'icon': cat['icon'],
        'color': cat['color'],
        'frequency': frequency,
        'next_date':
            now.add(Duration(days: nextInDays)).toUtc().toIso8601String(),
        'next_payment_amount': nextPaymentAmount,
        'amount_paid_previously': '0.00',
        'amount_left_to_pay': nextPaymentAmount,
        'total_amount_to_pay': nextPaymentAmount,
        'end_date': null,
        'start_date': now.subtract(const Duration(days: 90)).toUtc().toIso8601String(),
        'has_end_date': false,
        'is_active': isActive,
        'transaction_category': [
          _txCat(900 + id, cat, nextPaymentAmount),
        ],
      };
    }

    recurrences = [
      if (includeIncome)
        template(
          id: 5,
          name: 'Monthly salary',
          frequency: 'monthly',
          nextPaymentAmount: '3200.00',
          nextInDays: 3,
          isActive: true,
          catKey: 'salary',
        ),
      template(
        id: 1,
        name: 'Netflix',
        frequency: 'monthly',
        nextPaymentAmount: '15.99',
        nextInDays: 5,
        isActive: true,
        catKey: 'entertainment',
      ),
      template(
        id: 2,
        name: 'Rent',
        frequency: 'monthly',
        nextPaymentAmount: '1450.00',
        nextInDays: 12,
        isActive: true,
        catKey: 'housing',
      ),
      template(
        id: 3,
        name: 'Spotify',
        frequency: 'monthly',
        nextPaymentAmount: '11.99',
        nextInDays: 20,
        isActive: true,
        catKey: 'entertainment',
      ),
      template(
        id: 4,
        name: 'Gym Membership',
        frequency: 'monthly',
        nextPaymentAmount: '39.99',
        nextInDays: 26,
        isActive: false,
        catKey: 'fitness',
      ),
    ];

    recurrenceTimeline = [
      for (final r in recurrences)
        for (final offset in [-14, 16])
          {
            'id': r['id'],
            'name': r['name'],
            'type': r['type'],
            'amount': r['next_payment_amount'],
            'currency': 'USD',
            'icon': r['icon'],
            'color': r['color'],
            'date': now.add(Duration(days: offset)).toUtc().toIso8601String(),
          },
    ];
  }

  void _buildPatterns() {
    Map<String, dynamic> pattern({
      required int id,
      required String name,
      required String description,
      required String patternType,
      required double finalScore,
      required Map<String, dynamic> metadata,
      String icon = '',
      String color = '',
    }) {
      final iso = now.toUtc().toIso8601String();
      return {
        'id': id,
        'created_at': iso,
        'updated_at': iso,
        'name': name,
        'description': description,
        'metadata': metadata,
        'icon': icon,
        'color': color,
        'pattern_type': patternType,
        'final_score': finalScore,
        'profile_id': 1,
      };
    }

    patterns = [
      pattern(
        id: 1,
        name: 'Daily Habit: Coffee',
        description:
            "'Coffee' appears to be a daily habit with 14 purchases (3.8 per week) and a median interval of 1.8 days between purchases.",
        patternType: 'daily_habit',
        finalScore: 78.4,
        icon: 'mdi:coffee',
        color: '#6D4C41',
        metadata: {
          'category': 'Coffee',
          'transactionCount': 14,
          'purchasesPerWeek': 3.8,
          'medianInterval': 1.8,
          'totalAmount': 87.5,
          'averageAmount': 6.25,
          'patternType': 'daily_habit',
        },
      ),
      pattern(
        id: 2,
        name: 'Weekend Spending Spike',
        description:
            'Your average weekend spending (\$62.40) is 41.2% higher than your weekday spending (\$44.20). Consider reviewing your weekend expenses.',
        patternType: 'weekend_spike',
        finalScore: 64.1,
        icon: 'mdi:calendar-weekend',
        color: '#FDAA00',
        metadata: {
          'weekendAvg': 62.4,
          'weekdayAvg': 44.2,
          'percentDiff': 0.412,
          'totalAmount': 1245.5,
          'totalAvg': 18.32,
          'transactionsCount': 25,
        },
      ),
      pattern(
        id: 3,
        name: 'Top Category: Groceries',
        description:
            "'Groceries' is your top spending category this period, making up 28.4% of total expenses.",
        patternType: 'top_category',
        finalScore: 55.0,
        icon: 'mdi:cart',
        color: '#1F8A3F',
        metadata: {'category': 'Groceries', 'percentage': 28.4},
      ),
      pattern(
        id: 4,
        name: 'Weekly Repeat: Groceries',
        description:
            "'Groceries' purchases repeat roughly every 5 days — looks like a weekly shopping habit.",
        patternType: 'weekly_repeat',
        finalScore: 48.7,
        icon: 'mdi:repeat',
        color: '#0984E3',
        metadata: {
          'category': 'Groceries',
          'transactionCount': 8,
          'purchasesPerWeek': 1.1,
          'medianInterval': 5.0,
          'totalAmount': 412.6,
          'averageAmount': 51.6,
        },
      ),
      pattern(
        id: 5,
        name: 'Infrequent Splurge: Travel',
        description:
            "'Travel' purchases are rare but large — averaging \$412.60 across 1 purchase this period.",
        patternType: 'infrequent_splurge',
        finalScore: 41.3,
        icon: 'mdi:airplane',
        color: '#8E44AD',
        metadata: {
          'category': 'Travel',
          'transactionCount': 1,
          'totalAmount': 412.6,
          'averageAmount': 412.6,
        },
      ),
      pattern(
        id: 6,
        name: 'High Concentration: Housing',
        description:
            "'Rent & Housing' alone makes up 34.1% of your total spending — a large share in one category.",
        patternType: 'high_concentration',
        finalScore: 36.9,
        icon: 'mdi:chart-donut',
        color: '#00CEC9',
        metadata: {'category': 'Rent & Housing', 'percentage': 34.1},
      ),
    ];
  }

  // ── response builders ──────────────────────────────────────────────

  Map<String, dynamic> listTransactionsResponse({bool empty = false}) {
    final results = empty ? const <Map<String, dynamic>>[] : transactions;
    return {
      'count': results.length,
      'total_pages': 1,
      'current_page': 1,
      'per_page': results.isEmpty ? 20 : results.length,
      'results': results,
    };
  }

  Map<String, dynamic>? transactionById(int id) {
    for (final t in transactions) {
      if (t['id'] == id) return t;
    }
    return null;
  }

  List<Map<String, dynamic>> categoriesResponse({required bool used}) {
    if (!used) return categories;
    // "Used" categories: only the ones that actually appear on a transaction.
    final used0 = <int>{};
    for (final t in transactions) {
      for (final c in (t['TransactionCategory'] as List)) {
        used0.add((c as Map<String, dynamic>)['category_id'] as int);
      }
    }
    return categories.where((c) => used0.contains(c['id'])).toList();
  }

  bool _sameMonth(DateTime d, DateTime ref) =>
      d.year == ref.year && d.month == ref.month;

  List<Map<String, dynamic>> _txInMonth(DateTime ref) => transactions
      .where((t) => _sameMonth(DateTime.parse(t['date'] as String), ref))
      .toList();

  Map<String, dynamic> dashboard({bool empty = false}) {
    // Local month bounds, as the app sends them (DashboardPeriodKind.range).
    final periodStart = DateTime(now.year, now.month, 1).toUtc();
    final periodEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59).toUtc();
    if (empty) {
      return {
        'period': {
          'start_date': periodStart.toIso8601String(),
          'end_date': periodEnd.toIso8601String(),
        },
        'currency_code': 'USD',
        'balance': '0',
        'total_income': '0',
        'total_expense': '0',
        'recent_transactions': <Map<String, dynamic>>[],
        'quick_stats': {
          'top_category': null,
          'avg_daily_spend': '0',
          'transaction_count': 0,
          'savings_rate': '0',
          'biggest_transaction': {
            'name': '',
            'amount': '0',
            'icon': '',
            'color': '',
          },
          'top_merchant': {'name': '', 'amount': '0'},
          'avg_transaction': '0',
        },
        'upcoming_recurring': <Map<String, dynamic>>[],
      };
    }

    final monthTx = _txInMonth(now);
    final expenses = monthTx.where((t) => t['type'] == 'expense').toList();
    final incomes = monthTx.where((t) => t['type'] == 'income').toList();

    double sumOf(Iterable<Map<String, dynamic>> txs) {
      var total = 0.0;
      for (final t in txs) {
        for (final c in (t['TransactionCategory'] as List)) {
          total += double.parse((c as Map<String, dynamic>)['amount'] as String);
        }
      }
      return total;
    }

    final totalExpense = sumOf(expenses);
    final totalIncome = sumOf(incomes);

    final categoryTotals = <String, double>{};
    for (final t in expenses) {
      for (final c in (t['TransactionCategory'] as List)) {
        final cat = (c as Map<String, dynamic>)['Category'] as Map<String, dynamic>;
        final name = cat['name'] as String;
        categoryTotals[name] =
            (categoryTotals[name] ?? 0) + double.parse(c['amount'] as String);
      }
    }
    final topCategoryEntry = categoryTotals.entries.isEmpty
        ? null
        : (categoryTotals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first;
    final topCategoryId = topCategoryEntry == null
        ? null
        : categories.firstWhere((c) => c['name'] == topCategoryEntry.key)['id'];

    final merchantTotals = <String, double>{};
    for (final t in expenses) {
      final m = t['merchant_name'] as String;
      if (m.isEmpty) continue;
      merchantTotals[m] = (merchantTotals[m] ?? 0) +
          double.parse(
            (t['TransactionCategory'] as List)
                .cast<Map<String, dynamic>>()
                .fold(0.0, (s, c) => s + double.parse(c['amount'] as String))
                .toString(),
          );
    }
    final topMerchantEntry = merchantTotals.entries.isEmpty
        ? null
        : (merchantTotals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first;

    Map<String, dynamic> biggest = {
      'name': '',
      'amount': '0',
      'icon': '',
      'color': '',
    };
    var biggestAmount = -1.0;
    for (final t in expenses) {
      final amount = (t['TransactionCategory'] as List)
          .cast<Map<String, dynamic>>()
          .fold(0.0, (s, c) => s + double.parse(c['amount'] as String));
      if (amount > biggestAmount) {
        biggestAmount = amount;
        biggest = {
          'name': t['name'],
          'amount': amount.toStringAsFixed(2),
          'icon': t['icon'],
          'color': t['color'],
        };
      }
    }

    final daysSoFar = now.day;
    final recent = ([...monthTx]
          ..sort((a, b) =>
              (b['date'] as String).compareTo(a['date'] as String)))
        .take(10)
        .toList();

    return {
      'period': {
        'start_date': periodStart.toIso8601String(),
        'end_date': periodEnd.toIso8601String(),
      },
      'currency_code': 'USD',
      'balance': (totalIncome - totalExpense).toStringAsFixed(2),
      'total_income': totalIncome.toStringAsFixed(2),
      'total_expense': totalExpense.toStringAsFixed(2),
      'recent_transactions': recent,
      'quick_stats': {
        'top_category': topCategoryEntry == null
            ? null
            : {
                'category_id': topCategoryId,
                'category_name': topCategoryEntry.key,
                'total_amount': topCategoryEntry.value.toStringAsFixed(2),
              },
        'avg_daily_spend': (totalExpense / daysSoFar).toStringAsFixed(2),
        'transaction_count': monthTx.length,
        'savings_rate': totalIncome == 0
            ? '0'
            : (((totalIncome - totalExpense) / totalIncome) * 100)
                .toStringAsFixed(1),
        'biggest_transaction': biggest,
        'top_merchant': topMerchantEntry == null
            ? {'name': '', 'amount': '0'}
            : {
                'name': topMerchantEntry.key,
                'amount': topMerchantEntry.value.toStringAsFixed(2),
              },
        'avg_transaction': expenses.isEmpty
            ? '0'
            : (totalExpense / expenses.length).toStringAsFixed(2),
      },
      'upcoming_recurring': [
        for (final r in recurrences.where((r) => r['is_active'] == true))
          {
            'name': r['name'],
            'type': r['type'],
            'amount': r['next_payment_amount'],
            'date': r['next_date'],
          },
      ],
    };
  }

  Map<String, dynamic> analysis({bool empty = false}) {
    final monthStart = DateTime.utc(now.year, now.month, 1);
    final lastMonthStart = DateTime.utc(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime.utc(now.year, now.month, 0);

    List<Map<String, dynamic>> categorySummary(DateTime monthRef) {
      final txs = empty
          ? const <Map<String, dynamic>>[]
          : _txInMonth(monthRef).where((t) => t['type'] == 'expense');
      final totals = <String, double>{};
      final meta = <String, Map<String, dynamic>>{};
      for (final t in txs) {
        for (final c in (t['TransactionCategory'] as List)) {
          final cat =
              (c as Map<String, dynamic>)['Category'] as Map<String, dynamic>;
          final name = cat['name'] as String;
          totals[name] = (totals[name] ?? 0) + double.parse(c['amount'] as String);
          meta[name] = cat;
        }
      }
      final grand = totals.values.fold(0.0, (a, b) => a + b);
      final entries = totals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return [
        for (final e in entries)
          {
            'category_id': meta[e.key]!['id'],
            'category_name': e.key,
            'total_amount': e.value.toStringAsFixed(2),
            'percentage':
                grand == 0 ? '0' : ((e.value / grand) * 100).toStringAsFixed(1),
            'icon': meta[e.key]!['icon'],
            'color': meta[e.key]!['color'],
          },
      ];
    }

    List<Map<String, dynamic>> spentPerDay(DateTime start, DateTime end) {
      final totalsByDay = <String, double>{};
      if (!empty) {
        for (final t in transactions.where((t) => t['type'] == 'expense')) {
          final d = DateTime.parse(t['date'] as String);
          if (d.isBefore(start) || d.isAfter(end)) continue;
          final key = '${d.year}-${d.month}-${d.day}';
          final amount = (t['TransactionCategory'] as List)
              .cast<Map<String, dynamic>>()
              .fold(0.0, (s, c) => s + double.parse(c['amount'] as String));
          totalsByDay[key] = (totalsByDay[key] ?? 0) + amount;
        }
      }
      final out = <Map<String, dynamic>>[];
      for (var d = start;
          !d.isAfter(end);
          d = d.add(const Duration(days: 1))) {
        final key = '${d.year}-${d.month}-${d.day}';
        out.add({
          'date': d.toIso8601String(),
          'amount': (totalsByDay[key] ?? 0).toStringAsFixed(2),
        });
      }
      return out;
    }

    final currentCats = categorySummary(now);
    final lastCats = categorySummary(lastMonthStart);
    final total = currentCats.fold(
        0.0, (s, c) => s + double.parse(c['total_amount'] as String));

    final expensesThisMonth = empty
        ? const <Map<String, dynamic>>[]
        : _txInMonth(now).where((t) => t['type'] == 'expense').toList();
    final biggest = expensesThisMonth.isEmpty
        ? {'name': '', 'amount': '0', 'icon': '', 'color': ''}
        : (expensesThisMonth.toList()
              ..sort((a, b) {
                double amt(Map<String, dynamic> t) => (t['TransactionCategory']
                        as List)
                    .cast<Map<String, dynamic>>()
                    .fold(0.0, (s, c) => s + double.parse(c['amount'] as String));
                return amt(b).compareTo(amt(a));
              }))
            .map((t) => {
                  'name': t['name'],
                  'amount': (t['TransactionCategory'] as List)
                      .cast<Map<String, dynamic>>()
                      .fold(0.0, (s, c) => s + double.parse(c['amount'] as String))
                      .toStringAsFixed(2),
                  'icon': t['icon'],
                  'color': t['color'],
                })
            .first;

    return {
      'categories': currentCats,
      'categories_last_period': lastCats,
      'spent_per_day': spentPerDay(monthStart, now),
      'spent_per_day_last_period': spentPerDay(lastMonthStart, lastMonthEnd),
      'next_recurring_transactions': [
        for (final r in recurrences.where((r) => r['is_active'] == true))
          {
            'amount': r['next_payment_amount'],
            'date': r['next_date'],
            'name': r['name'],
          },
      ],
      'total': total.toStringAsFixed(2),
      'quick_stats': {
        'savings_rate': '18.5',
        'biggest_transaction': biggest,
        'transaction_count': expensesThisMonth.length,
        'top_merchant': expensesThisMonth.isEmpty
            ? {'name': '', 'amount': '0'}
            : {'name': 'Costco', 'amount': '165.30'},
        'avg_transaction': expensesThisMonth.isEmpty
            ? '0'
            : (total / expensesThisMonth.length).toStringAsFixed(2),
      },
    };
  }
}
