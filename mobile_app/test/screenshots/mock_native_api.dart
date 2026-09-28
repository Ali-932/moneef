// Mocks the `moneef/api` MethodChannel that `lib/services/native_api.dart`
// talks to, so screens can be rendered in a widget test without the (Android
// x86_64-crashing) Go .aar. See `fixtures.dart` for the canned data.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

const _channel = MethodChannel('moneef/api');

Map<String, dynamic> _decodePayload(MethodCall call) {
  final args = call.arguments;
  if (args is Map) {
    final payload = args['payload'];
    if (payload is List<int>) {
      final decoded = jsonDecode(utf8.decode(payload));
      if (decoded is Map<String, dynamic>) return decoded;
    }
  }
  return const {};
}

/// Installs a mock handler for the native bridge channel, backed by
/// [fixtures]. Pass [emptyData] for the "brand new user" screenshots (no
/// transactions yet).
void installNativeApiMock(Fixtures fixtures, {bool emptyData = false}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
    switch (call.method) {
      case 'listTransactions':
        return jsonBytes(fixtures.listTransactionsResponse(empty: emptyData));
      case 'getTransaction':
        final id = (call.arguments as Map)['id'] as int;
        return jsonBytes(fixtures.transactionById(id));
      case 'listRecurrences':
        return jsonBytes(fixtures.recurrences);
      case 'recurrenceTimeline':
        return jsonBytes(fixtures.recurrenceTimeline);
      case 'listCurrencies':
        return jsonBytes(fixtures.currencies);
      case 'listExchangeRates':
        return jsonBytes(fixtures.exchangeRates);
      case 'listCategories':
        final body = _decodePayload(call);
        return jsonBytes(
          fixtures.categoriesResponse(used: body['used'] == true),
        );
      case 'dashboard':
        return jsonBytes(fixtures.dashboard(empty: emptyData));
      case 'analysis':
        return jsonBytes(fixtures.analysis(empty: emptyData));
      case 'patterns':
      case 'refreshPatterns':
        return jsonBytes(emptyData ? const [] : fixtures.patterns);
      case 'getProfile':
        return jsonBytes(fixtures.profile);
      case 'getSettings':
        return jsonBytes(fixtures.settings);
      case 'init':
      case 'shutdown':
      case 'setProfileId':
      case 'createTransaction':
      case 'updateTransaction':
      case 'deleteTransaction':
      case 'updateRecurrence':
      case 'deleteRecurrence':
      case 'createCategory':
      case 'updateCategory':
      case 'deleteCategory':
      case 'updateProfile':
      case 'updateSettings':
      case 'upsertExchangeRate':
      case 'fetchExchangeRates':
        // Not exercised by the screenshot harness — no screen tap submits a
        // mutation, so these are never actually invoked.
        return null;
    }
    throw MissingPluginException('No screenshot fixture for ${call.method}');
  });
}
