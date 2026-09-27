// Build with ORG_GRADLE_PROJECT_backupProof=true flutter build apk --debug
// --target=tool/backup_device_proof.dart. Uses a separate application ID.
// On a device: run creation proof, uninstall ONLY .backupproof, reinstall,
// run reinstall proof and choose the same local folder again.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mobile_app/services/backup_service.dart';
import 'package:mobile_app/services/native_api.dart';
import 'package:mobile_app/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(theme: buildAppTheme(Brightness.light), home: const Proof()),
  );
}

class Proof extends StatefulWidget {
  const Proof({super.key});
  @override
  State<Proof> createState() => _ProofState();
}

class _ProofState extends State<Proof> {
  final service = BackupService();
  final api = NativeApi.instance;
  String status = 'Isolated backup proof. Choose a dedicated test folder.';
  bool busy = false;
  void check(bool condition, String reason) {
    if (!condition) throw StateError(reason);
  }

  Future<void> run(bool reinstall) async {
    setState(() => busy = true);
    try {
      final support = await getApplicationSupportDirectory();
      final path = '${support.path}/backup-proof.sqlite';
      check(
        !File(path).existsSync(),
        'Proof requires a fresh .backupproof installation.',
      );
      await api.init(dbPath: path);
      final folder = await service.chooseFolder();
      check(folder != null, 'Folder picker cancelled');
      if (reinstall) {
        final copies = await service.list(folder!);
        check(copies.backups.isNotEmpty, 'No backups survived uninstall');
        final one = copies.backups.firstWhere((b) => b.transactionCount == 1);
        final id = await service.restore(folder, one);
        check(id > 0, 'Profile not restored');
        check(
          (await api.listTransactions({}))['count'] == 1,
          'Transaction did not survive reinstall',
        );
        check(
          (await api.getSettings())['is_dark_mode'] == true,
          'Preferences missing',
        );
        check(
          (await api.getProfile())['first_name'] == 'Backup',
          'Profile missing',
        );
        setState(
          () => status =
              'PASS: real uninstall/reinstall, folder reselection, transactions, profile and settings.',
        );
      } else {
        await api.setup(
          firstName: 'Backup',
          lastName: 'Proof',
          currencyCode: 'USD',
        );
        final category = await api.createCategory({
          'name': 'Backup proof',
          'type': 'expense',
          'icon': 'mdi:coffee',
          'color': '#7B3F00',
        });
        final transaction = {
          'transaction_name': 'Offline proof',
          'transaction_type': 'expense',
          'currency_code': 'USD',
          'date': DateTime.now().toUtc().toIso8601String(),
          'transaction_categories': [
            {'category_id': category['id'], 'amount': '640000.75'},
          ],
        };
        await api.createTransaction(transaction);
        await api.updateSettings({'is_dark_mode': true});
        await service.configure(folder!);
        final copies = await service.list(folder);
        check(copies.backups.isNotEmpty, 'No first backup');
        final original = copies.backups.first;
        check(original.transactionCount == 1, 'First backup count wrong');
        await api.createTransaction(transaction);
        final updated = await service.list(folder);
        check(
          updated.backups.first.transactionCount == 2,
          'Automatic backup did not update',
        );
        await service.restore(folder, original);
        check(
          (await api.listTransactions({}))['count'] == 1,
          'Restore did not replace data',
        );
        await service.backupNow();
        check(
          (await service.list(folder)).backups.first.transactionCount == 1,
          'Manual backup failed',
        );
        setState(
          () => status =
              'PASS: SAF write, automatic backup after mutation, listing, restore and manual backup. Ready for uninstall/reinstall proof.',
        );
      }
      // The test runner can capture one structured line from adb logcat.
      debugPrint('MONEEF_BACKUP_PROOF ${jsonEncode({'status': status})}');
    } catch (e, stack) {
      setState(() => status = 'FAIL: $e');
      debugPrint('MONEEF_BACKUP_PROOF $e\n$stack');
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Backup device proof')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(status, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy ? null : () => run(false),
            child: const Text('Run creation proof'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: busy ? null : () => run(true),
            child: const Text('Verify after reinstall'),
          ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
    ),
  );
}
