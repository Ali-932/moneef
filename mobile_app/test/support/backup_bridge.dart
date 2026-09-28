import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class BackupBridge {
  final status = <String, Object?>{
    'supported': true,
    'enabled': false,
    'busy': false,
    'dismissed': false,
  };
  bool cancelPicker = false;
  bool failBackup = false;
  bool failRestore = false;
  bool empty = false;
  int restored = 0;
  int configured = 0;
  int manual = 0;
  void Function()? onRestore;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('moneef/backups'), (
          call,
        ) async {
          switch (call.method) {
            case 'status':
              return status;
            case 'chooseFolder':
              return cancelPicker
                  ? null
                  : {
                      'uri': 'content://local/tree/test',
                      'name': 'Internal storage / Documents/Moneef Backups',
                    };
            case 'configure':
              configured++;
              status.addAll({
                'enabled': true,
                'folder': 'content://local/tree/test',
                'folderName': 'Internal storage / Documents/Moneef Backups',
              });
              if (failBackup) {
                throw PlatformException(
                  code: 'BACKUP_ERROR',
                  message:
                      'Folder is unavailable. Your data is still saved in Moneef.',
                );
              }
              status['lastBackup'] = '2026-09-26T09:30:00Z';
              return status;
            case 'backupNow':
              manual++;
              if (failBackup) {
                throw PlatformException(
                  code: 'BACKUP_ERROR',
                  message:
                      'Folder is unavailable. Your data is still saved in Moneef.',
                );
              }
              status['lastBackup'] = '2026-09-26T10:30:00Z';
              status['error'] = null;
              return status;
            case 'dismiss':
              status['dismissed'] = true;
              return status;
            case 'list':
              return {
                'unreadable': 0,
                'backups': empty
                    ? []
                    : [
                        {
                          'uri': 'content://local/document/backup',
                          'createdAt': '2026-09-25T09:30:00Z',
                          'transactionCount': 1264,
                        },
                      ],
              };
            case 'restore':
              restored++;
              if (failRestore) {
                throw PlatformException(
                  code: 'BACKUP_ERROR',
                  message: 'Backup is incomplete or damaged.',
                );
              }
              onRestore?.call();
              return {'profileId': 42};
          }
          return null;
        });
  }
}
