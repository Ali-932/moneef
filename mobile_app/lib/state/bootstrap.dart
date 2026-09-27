import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/native_api.dart';

/// Outcome of the first-run boot sequence. Drives the splash → main UI hand-off.
enum BootStage { idle, initializing, welcome, ready, error }

class BootState {
  const BootState({required this.stage, this.profileId, this.error});

  final BootStage stage;
  final int? profileId;
  final Object? error;

  BootState copyWith({BootStage? stage, int? profileId, Object? error}) {
    return BootState(
      stage: stage ?? this.stage,
      profileId: profileId ?? this.profileId,
      error: error ?? this.error,
    );
  }

  static const initial = BootState(stage: BootStage.idle);
}

const _kProfileIdKey = 'moneef.profile_id';

/// Loads the active profile id from shared_preferences (if any), calls
/// `NativeApi.init`, and offers setup or local restore for first launchers.
/// CRUD is available when BootStage.ready is reached.
class BootController extends StateNotifier<BootState> {
  BootController(this._api) : super(BootState.initial);

  final NativeApi _api;

  Future<void> boot() async {
    if (state.stage == BootStage.initializing ||
        state.stage == BootStage.ready) {
      return;
    }
    state = state.copyWith(stage: BootStage.initializing);
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedProfileId = prefs.getInt(_kProfileIdKey) ?? 0;

      final supportDir = await getApplicationSupportDirectory();
      final dbDir = Directory('${supportDir.path}/moneef');
      if (!dbDir.existsSync()) {
        dbDir.createSync(recursive: true);
      }
      final dbPath = '${dbDir.path}/db.sqlite';

      try {
        await _api.init(dbPath: dbPath, profileId: storedProfileId);
      } on PlatformException catch (e) {
        // The Go core lives in the OS process, which outlives the Android
        // Activity. Leaving via the back button and returning re-runs boot()
        // and re-calls init; "already inited" just means the native core
        // survived from the previous Activity, so treat it as success.
        if (!(e.message?.contains(MoneefErrors.alreadyInited) ?? false)) {
          rethrow;
        }
      }

      final profileId = await _api.activeProfileId();
      if (profileId > 0) await prefs.setInt(_kProfileIdKey, profileId);
      state = BootState(
        stage: profileId > 0 ? BootStage.ready : BootStage.welcome,
        profileId: profileId,
      );
    } catch (e) {
      state = state.copyWith(stage: BootStage.error, error: e);
    }
  }

  Future<void> startFresh() async {
    if (state.stage != BootStage.welcome) return;
    state = const BootState(stage: BootStage.initializing);
    try {
      final resp = await _api.setup(
        firstName: 'Moneef',
        lastName: 'User',
        currencyCode: 'USD',
      );
      await completeRestore((resp['profile_id'] as num).toInt());
    } catch (e) {
      state = BootState(stage: BootStage.error, error: e);
    }
  }

  Future<void> completeRestore(int profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kProfileIdKey, profileId);
    state = BootState(stage: BootStage.ready, profileId: profileId);
  }
}

final nativeApiProvider = Provider<NativeApi>((_) => NativeApi.instance);

final bootControllerProvider = StateNotifierProvider<BootController, BootState>(
  (ref) {
    return BootController(ref.watch(nativeApiProvider));
  },
);
