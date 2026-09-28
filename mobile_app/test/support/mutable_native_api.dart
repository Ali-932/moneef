import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screenshots/fixtures.dart';

/// Exercises the real NativeApi serialization and providers against mutable
/// bridge responses. Dashboard and analysis fixtures derive from saved rows.
class MutableNativeApi {
  final fixtures = Fixtures();
  final calls = <String, int>{};
  final transactionPayloads = <Map<String, dynamic>>[];
  bool failCreate = false;
  bool failCategory = false;
  int lastTransactionId = 1000;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('moneef/api'), _handle);
  }

  Future<Object?> _handle(MethodCall call) async {
    calls.update(call.method, (n) => n + 1, ifAbsent: () => 1);
    final args = call.arguments as Map?;
    final bytes = args?['payload'] as List<int>?;
    final body = bytes == null
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    switch (call.method) {
      case 'createCategory':
        if (failCategory) {
          throw PlatformException(
            code: 'error',
            message: 'Category already exists',
          );
        }
        final category = {
          'id': 100 + fixtures.categories.length,
          'profile_id': 1,
          'icon': '',
          ...body,
        };
        fixtures.categories.add(category);
        return jsonBytes(category);
      case 'listCategories':
        return jsonBytes(
          fixtures.categoriesResponse(used: body['used'] == true),
        );
      case 'createTransaction':
      case 'updateTransaction':
        if (failCreate) {
          throw PlatformException(
            code: 'error',
            message: 'Could not save transaction',
          );
        }
        transactionPayloads.add(body);
        final id = call.method == 'createTransaction'
            ? ++lastTransactionId
            : args!['id'] as int;
        fixtures.transactions.removeWhere((t) => t['id'] == id);
        fixtures.transactions.insert(0, {
          'id': id,
          'name': body['transaction_name'],
          'type': body['transaction_type'],
          'date': body['date'],
          'currency_code': body['currency_code'],
          'merchant_name': body['merchant_name'] ?? '',
          'notes': body['notes'] ?? '',
          'icon': '',
          'color': '',
          'TransactionCategory': [
            for (final split in body['transaction_categories'] as List)
              {
                'id': split['category_id'],
                'transaction_id': id,
                ...split as Map<String, dynamic>,
                'Category': fixtures.categories.firstWhere(
                  (c) => c['id'] == split['category_id'],
                ),
              },
          ],
        });
        return jsonBytes({'message': 'saved'});
      case 'deleteTransaction':
        fixtures.transactions.removeWhere((t) => t['id'] == args!['id']);
        return null;
      case 'getTransaction':
        return jsonBytes(fixtures.transactionById(args!['id'] as int));
      case 'listTransactions':
        return jsonBytes(fixtures.listTransactionsResponse());
      case 'dashboard':
        return jsonBytes(fixtures.dashboard());
      case 'analysis':
        return jsonBytes(fixtures.analysis());
      case 'refreshPatterns':
        return jsonBytes(fixtures.patterns);
      case 'recurrenceTimeline':
        return jsonBytes(fixtures.recurrenceTimeline);
      case 'listCurrencies':
        return jsonBytes(fixtures.currencies);
      case 'listExchangeRates':
        return jsonBytes(fixtures.exchangeRates);
      case 'getSettings':
        return jsonBytes(fixtures.settings);
      case 'getProfile':
        return jsonBytes(fixtures.profile);
      default:
        throw MissingPluginException('No mutable fixture for ${call.method}');
    }
  }
}
