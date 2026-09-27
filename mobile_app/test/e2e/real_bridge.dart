// Real-core e2e harness: routes the `moneef/api` MethodChannel into the real
// Go `mobile` package (build/libmoneef_e2e.so, see mobile/_e2e/main.go) over
// dart:ffi. FFI calls are synchronous, so they work inside testWidgets'
// fake-async zone. Build the lib first:
//   go build -tags smoke -buildmode=c-shared -o build/libmoneef_e2e.so ./mobile/_e2e/
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _CallC = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _ResetC = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _FreeC = Void Function(Pointer<Utf8>);
typedef _FreeD = void Function(Pointer<Utf8>);

class RealBridge {
  RealBridge._() {
    final path =
        Platform.environment['MONEEF_E2E_LIB'] ?? '../build/libmoneef_e2e.so';
    final lib = DynamicLibrary.open(File(path).absolute.path);
    _call = lib.lookupFunction<_CallC, _CallC>('MoneefCall');
    _reset = lib.lookupFunction<_ResetC, _ResetC>('MoneefReset');
    _free = lib.lookupFunction<_FreeC, _FreeD>('MoneefFree');
    dbPath =
        '${Directory.systemTemp.createTempSync('moneef-e2e-').path}/db.sqlite';
  }
  static final RealBridge instance = RealBridge._();

  late final _CallC _call;
  late final _ResetC _reset;
  late final _FreeD _free;
  late final String dbPath;

  /// Every method the UI sent, in order (for asserting call shape).
  final calls = <MethodCall>[];

  /// Fresh empty DB (Init'd, no profile). Call in setUp.
  void reset() {
    calls.clear();
    final r = _reset(dbPath.toNativeUtf8());
    final err = r.toDartString();
    _free(r);
    if (err.isNotEmpty) throw StateError('MoneefReset: $err');
  }

  /// Fresh DB + completed first-run setup. Returns the profile id.
  int resetWithProfile({String currency = 'USD'}) {
    reset();
    final resp = json('setup', body: {
      'first_name': 'E2E',
      'last_name': 'Tester',
      'currency_code': currency,
      'language': 'en',
    }) as Map<String, dynamic>;
    return (resp['profile_id'] as num).toInt();
  }

  /// Raw call with MethodChannel-shaped args. Throws PlatformException on Go error.
  Object? invoke(String method, [Map? args]) {
    final a = <String, Object?>{};
    args?.forEach((k, v) {
      a[k as String] = v is List<int> ? base64Encode(v) : v;
    });
    final m = method.toNativeUtf8();
    final j = jsonEncode(a).toNativeUtf8();
    final r = _call(m, j);
    malloc.free(m);
    malloc.free(j);
    final out = jsonDecode(r.toDartString()) as Map<String, dynamic>;
    _free(r);
    if (out['ok'] != true) {
      throw PlatformException(code: 'MOBILE_ERROR', message: out['error'] as String?);
    }
    if (out['bytes'] != null) return base64Decode(out['bytes'] as String);
    return out['int'];
  }

  /// Direct verification helper: call Go with a JSON body, decode JSON result.
  Object? json(String method, {Map<String, dynamic>? body, int? id}) {
    final res = invoke(method, {
      if (body != null) 'payload': utf8.encode(jsonEncode(body)),
      if (id != null) 'id': id,
    });
    if (res is! List<int> || res.isEmpty) return res;
    return jsonDecode(utf8.decode(res));
  }

  /// Wire `moneef/api` → real Go, and stub `moneef/backups` as unsupported.
  void install() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(const MethodChannel('moneef/api'), (call) async {
      calls.add(call);
      final res = invoke(call.method, call.arguments as Map?);
      return res is List<int> ? Uint8List.fromList(res) : res;
    });
    m.setMockMethodCallHandler(const MethodChannel('moneef/backups'), (call) async {
      if (call.method == 'status') {
        return {'supported': false, 'enabled': false, 'busy': false, 'dismissed': true};
      }
      return null;
    });
  }

  int callCount(String method) => calls.where((c) => c.method == method).length;
}
