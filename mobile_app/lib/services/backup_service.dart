import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackupStatus {
  const BackupStatus({
    this.supported = true,
    this.enabled = false,
    this.busy = false,
    this.dismissed = false,
    this.folder,
    this.folderName,
    this.lastBackup,
    this.error,
  });

  factory BackupStatus.fromMap(Map<dynamic, dynamic> map) => BackupStatus(
    supported: map['supported'] == true,
    enabled: map['enabled'] == true,
    busy: map['busy'] == true,
    dismissed: map['dismissed'] == true,
    folder: map['folder'] as String?,
    folderName: map['folderName'] as String?,
    lastBackup: DateTime.tryParse(
      map['lastBackup'] as String? ?? '',
    )?.toLocal(),
    error: map['error'] as String?,
  );

  final bool supported, enabled, busy, dismissed;
  final String? folder, folderName, error;
  final DateTime? lastBackup;
}

class BackupFolder {
  const BackupFolder(this.uri, this.name);
  final String uri, name;
}

class LocalBackup {
  LocalBackup.fromMap(Map<dynamic, dynamic> map)
    : uri = map['uri'] as String,
      createdAt = DateTime.parse(map['createdAt'] as String).toLocal(),
      transactionCount = (map['transactionCount'] as num).toInt();
  final String uri;
  final DateTime createdAt;
  final int transactionCount;
}

class BackupListing {
  const BackupListing(this.backups, this.unreadable);
  final List<LocalBackup> backups;
  final int unreadable;
}

class BackupService {
  BackupService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'statusChanged') {
        _updates.add(BackupStatus.fromMap(call.arguments as Map));
      }
    });
  }

  static const _channel = MethodChannel('moneef/backups');
  final _updates = StreamController<BackupStatus>.broadcast();

  void dispose() {
    _channel.setMethodCallHandler(null);
    _updates.close();
  }

  Stream<BackupStatus> watch() async* {
    try {
      yield BackupStatus.fromMap(
        await _channel.invokeMapMethod('status') ?? {},
      );
      yield* _updates.stream;
    } on MissingPluginException {
      yield const BackupStatus(supported: false);
    }
  }

  Future<BackupFolder?> chooseFolder() async {
    final map = await _channel.invokeMapMethod('chooseFolder');
    if (map == null) return null;
    return BackupFolder(map['uri'] as String, map['name'] as String);
  }

  Future<void> configure(BackupFolder folder) =>
      _update('configure', {'folder': folder.uri});
  Future<void> backupNow() => _update('backupNow');
  Future<void> dismiss() => _update('dismiss');

  Future<void> _update(String method, [Map<String, Object>? args]) async {
    final value = await _channel.invokeMapMethod(method, args);
    if (value != null) _updates.add(BackupStatus.fromMap(value));
  }

  Future<BackupListing> list(BackupFolder folder) async {
    final map = await _channel.invokeMapMethod('list', {'folder': folder.uri});
    return BackupListing(
      (map?['backups'] as List? ?? [])
          .map((e) => LocalBackup.fromMap(e as Map))
          .toList(),
      (map?['unreadable'] as num? ?? 0).toInt(),
    );
  }

  Future<int> restore(BackupFolder folder, LocalBackup backup) async {
    final map = await _channel.invokeMapMethod('restore', {
      'folder': folder.uri,
      'uri': backup.uri,
    });
    return (map!['profileId'] as num).toInt();
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  final service = BackupService();
  ref.onDispose(service.dispose);
  return service;
});
final backupStatusProvider = StreamProvider<BackupStatus>(
  (ref) => ref.watch(backupServiceProvider).watch(),
);
