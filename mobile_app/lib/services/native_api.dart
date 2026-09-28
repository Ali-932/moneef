import 'dart:convert';

import 'package:flutter/services.dart';

/// Sentinel error strings emitted by the Go `mobilebridge/` shim.
/// Documented in `mobilebridge/API.md` § Error model.
class MoneefErrors {
  static const notInitialized = 'mobile: Init has not been called';
  static const alreadyInited = 'mobile: Init has already been called';
  static const profileNotSet =
      'mobile: profile id is not set; call SetProfileID or pass it to Init';
  static const invalidPayload = 'mobile: invalid JSON payload';
}

/// Thin Dart wrapper around the `moneef/api` MethodChannel.
///
/// Every method here mirrors one exported function in `mobilebridge/API.md`.
/// All payloads are UTF-8 JSON bytes. Numeric IDs are 64-bit.
///
/// Returned `Map`/`List` values are the raw JSON-decoded structures —
/// upper layers should wrap them in freezed models (see `lib/models/`).
class NativeApi {
  NativeApi._internal();
  static final NativeApi instance = NativeApi._internal();

  static const MethodChannel _channel = MethodChannel('moneef/api');

  // ── lifecycle ─────────────────────────────────────────────────────

  /// Opens the SQLite database at [dbPath], runs migrations, loads the
  /// merchant-icon cache, seeds default categories, and (optionally)
  /// pins [profileId] as the active profile.
  ///
  /// Pass `profileId: 0` on first run — call [setup] right after to
  /// receive a fresh profile id.
  Future<void> init({required String dbPath, int profileId = 0}) {
    return _invoke<void>('init', {'dbPath': dbPath, 'profileId': profileId});
  }

  Future<void> shutdown() => _invoke<void>('shutdown');

  Future<int> activeProfileId() => _invoke<int>('activeProfileId');

  Future<void> setProfileId(int id) =>
      _invoke<void>('setProfileId', {'id': id});

  // ── setup ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> setup({
    required String firstName,
    required String lastName,
    required String currencyCode,
    String language = 'en',
  }) {
    return _invokeJson('setup', {
      'first_name': firstName,
      'last_name': lastName,
      'currency_code': currencyCode,
      'language': language,
    });
  }

  // ── transactions ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> body) =>
      _invokeJson('createTransaction', body);

  Future<Map<String, dynamic>> listTransactions(Map<String, dynamic> filters) =>
      _invokeJson('listTransactions', filters);

  Future<Map<String, dynamic>> getTransaction(int id) =>
      _invokeJsonNoBody('getTransaction', id: id);

  Future<Map<String, dynamic>> updateTransaction(
    int id,
    Map<String, dynamic> body,
  ) => _invokeJson('updateTransaction', body, id: id);

  Future<void> deleteTransaction(int id) =>
      _invoke<void>('deleteTransaction', {'id': id});

  // ── recurrences ───────────────────────────────────────────────────

  Future<List<dynamic>> listRecurrences() => _invokeJsonList('listRecurrences');

  Future<List<dynamic>> recurrenceTimeline() =>
      _invokeJsonList('recurrenceTimeline');

  Future<void> deleteRecurrence(int id) =>
      _invoke<void>('deleteRecurrence', {'id': id});

  Future<void> updateRecurrence(int id, Map<String, dynamic> body) =>
      _invoke<void>('updateRecurrence', {
        'id': id,
        'payload': _encodeBody(body),
      });

  // ── currencies ─────────────────────────────────────────────────────

  Future<List<dynamic>> listCurrencies() => _invokeJsonList('listCurrencies');

  // ── exchange rates ─────────────────────────────────────────────────

  Future<List<dynamic>> listExchangeRates({String base = ''}) =>
      _invokeJsonList('listExchangeRates', body: {'base': base});

  Future<void> upsertExchangeRate({
    required String from,
    required String to,
    required String rate,
  }) => _invoke<void>('upsertExchangeRate', {
    'payload': _encodeBody({'from': from, 'to': to, 'rate': rate}),
  });

  Future<void> fetchExchangeRates() => _invoke<void>('fetchExchangeRates');

  // ── categories ────────────────────────────────────────────────────

  /// Lists categories visible to the active profile.
  ///
  /// Pass `{}` to fetch everything (defaults + profile-owned).
  /// Filters mirror `mobilebridge/API.md` § ListCategories.
  Future<List<dynamic>> listCategories({
    String type = '',
    bool custom = false,
    bool used = false,
  }) {
    return _invokeJsonList(
      'listCategories',
      body: {'type': type, 'custom': custom, 'used': used},
    );
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> body) =>
      _invokeJson('createCategory', body);

  Future<void> updateCategory(int id, Map<String, dynamic> body) =>
      _invoke<void>('updateCategory', {'id': id, 'payload': _encodeBody(body)});

  Future<void> deleteCategory(int id) =>
      _invoke<void>('deleteCategory', {'id': id});

  // ── dashboard & analysis ──────────────────────────────────────────

  Future<Map<String, dynamic>> dashboard({DateTime? from, DateTime? to}) {
    return _invokeJson('dashboard', {
      if (from != null) 'date_from': from.toUtc().toIso8601String(),
      if (to != null) 'date_to': to.toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> analysis({
    required DateTime startDate,
    required DateTime endDate,
    String currency = '',
  }) {
    return _invokeJson('analysis', {
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endDate.toUtc().toIso8601String(),
      // Go groups the daily chart by calendar days in this zone.
      'tz_offset_minutes': startDate.toLocal().timeZoneOffset.inMinutes,
      if (currency.isNotEmpty) 'currency': currency,
    });
  }

  // ── patterns ──────────────────────────────────────────────────────

  Future<List<dynamic>> patterns() => _invokeJsonList('patterns');

  Future<List<dynamic>> refreshPatterns({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _invokeJsonList(
      'refreshPatterns',
      body: {
        if (startDate != null)
          'start_date': startDate.toUtc().toIso8601String(),
        if (endDate != null) 'end_date': endDate.toUtc().toIso8601String(),
      },
    );
  }

  // ── profile & settings ────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() => _invokeJsonNoBody('getProfile');

  Future<void> updateProfile(Map<String, dynamic> body) =>
      _invoke<void>('updateProfile', {'payload': _encodeBody(body)});

  Future<Map<String, dynamic>> getSettings() =>
      _invokeJsonNoBody('getSettings');

  Future<void> updateSettings(Map<String, dynamic> body) =>
      _invoke<void>('updateSettings', {'payload': _encodeBody(body)});

  // ── internals ─────────────────────────────────────────────────────

  Uint8List _encodeBody(Map<String, dynamic> body) =>
      Uint8List.fromList(utf8.encode(jsonEncode(body)));

  /// Invokes [method] with a JSON body and decodes the `[]byte` response
  /// into a `Map<String, dynamic>`.
  Future<Map<String, dynamic>> _invokeJson(
    String method,
    Map<String, dynamic> body, {
    int? id,
  }) async {
    final args = <String, dynamic>{
      'payload': _encodeBody(body),
      if (id != null) 'id': id,
    };
    final bytes = await _channel.invokeMethod<Uint8List>(method, args);
    return _decodeJsonMap(bytes);
  }

  /// Variant for methods that take only an `id` (no body) but return JSON.
  Future<Map<String, dynamic>> _invokeJsonNoBody(
    String method, {
    int? id,
  }) async {
    final args = id != null ? <String, dynamic>{'id': id} : null;
    final bytes = await _channel.invokeMethod<Uint8List>(method, args);
    return _decodeJsonMap(bytes);
  }

  /// Variant for methods that return a JSON array.
  Future<List<dynamic>> _invokeJsonList(
    String method, {
    Map<String, dynamic>? body,
  }) async {
    final args = body == null
        ? null
        : <String, dynamic>{'payload': _encodeBody(body)};
    final bytes = await _channel.invokeMethod<Uint8List>(method, args);
    if (bytes == null || bytes.isEmpty) return <dynamic>[];
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is List) return decoded;
    throw FormatException(
      'NativeApi.$method: expected JSON array, got ${decoded.runtimeType}',
    );
  }

  Future<T> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    final r = await _channel.invokeMethod<T>(method, args);
    return r as T;
  }

  Map<String, dynamic> _decodeJsonMap(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is Map<String, dynamic>) return decoded;
    throw FormatException(
      'NativeApi: expected JSON object, got ${decoded.runtimeType}',
    );
  }
}
